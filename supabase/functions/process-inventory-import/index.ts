import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { jobId } = await req.json();
    if (!jobId) {
      return new Response(JSON.stringify({ error: "Missing jobId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    // Fetch the import job
    const { data: job, error: jobErr } = await supabase
      .from("inventory_import_jobs")
      .select("*")
      .eq("id", jobId)
      .single();

    if (jobErr || !job) {
      return new Response(JSON.stringify({ error: "Import job not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Mark as processing
    await supabase
      .from("inventory_import_jobs")
      .update({ status: "processing", started_at: new Date().toISOString() })
      .eq("id", jobId);

    // Download the CSV from storage
    const { data: fileData, error: dlErr } = await supabase.storage
      .from("inventory-imports")
      .download(job.file_path);

    if (dlErr || !fileData) {
      await supabase
        .from("inventory_import_jobs")
        .update({ status: "failed", error_message: "Could not download file", completed_at: new Date().toISOString() })
        .eq("id", jobId);
      return new Response(JSON.stringify({ error: "File download failed" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const csvText = await fileData.text();
    const lines = csvText.split("\n").filter((l) => l.trim());
    if (lines.length < 2) {
      await supabase
        .from("inventory_import_jobs")
        .update({ status: "failed", error_message: "Empty CSV", completed_at: new Date().toISOString() })
        .eq("id", jobId);
      return new Response(JSON.stringify({ error: "Empty CSV" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse header
    const headers = parseCSVLine(lines[0]).map((h) => h.trim().toLowerCase());

    // Find column indexes (default mapping)
    const colMap = resolveColumns(headers);
    if (!colMap.sku || !colMap.name) {
      await supabase
        .from("inventory_import_jobs")
        .update({ status: "failed", error_message: "Missing required columns (SKU and product name)", completed_at: new Date().toISOString() })
        .eq("id", jobId);
      return new Response(JSON.stringify({ error: "Missing required columns" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const totalRows = lines.length - 1;
    await supabase
      .from("inventory_import_jobs")
      .update({ total_rows: totalRows })
      .eq("id", jobId);

    // Fetch branch_id from job
    const branchId = job.branch_id;

    // Fetch existing categories for quick lookup
    const { data: existingCats } = await supabase
      .from("categories")
      .select("id, name, slug")
      .eq("is_active", true);

    const catMap = new Map<string, string>();
    (existingCats || []).forEach((c: any) => {
      catMap.set(c.name.toLowerCase(), c.id);
      catMap.set(c.slug.toLowerCase(), c.id);
    });

    // Fetch existing products by SKU
    const { data: existingProducts } = await supabase
      .from("products")
      .select("id, sku, slug")
      .eq("is_active", true);

    const productBySku = new Map<string, string>();
    (existingProducts || []).forEach((p: any) => {
      if (p.sku) productBySku.set(p.sku.toLowerCase(), p.id);
    });

    // Fetch existing branch_products for this branch
    const { data: existingBP } = await supabase
      .from("branch_products")
      .select("id, product_id, stock_quantity, selling_price")
      .eq("branch_id", branchId);

    const bpByProduct = new Map<string, any>();
    (existingBP || []).forEach((bp: any) => {
      bpByProduct.set(bp.product_id, bp);
    });

    let processed = 0;
    let successful = 0;
    let failed = 0;
    let skipped = 0;
    const batchSize = 500;
    let batchProducts: any[] = [];
    let batchBP: any[] = [];
    let batchChanges: any[] = [];
    let batchErrors: any[] = [];

    for (let i = 1; i < lines.length; i++) {
      const row = parseCSVLine(lines[i]);
      const sku = colMap.sku >= 0 ? row[colMap.sku]?.trim() : "";
      const name = colMap.name >= 0 ? row[colMap.name]?.trim() : "";
      const categoryName = colMap.category >= 0 ? row[colMap.category]?.trim() : "";
      const qtyStr = colMap.qty >= 0 ? row[colMap.qty]?.trim() : "0";
      const priceStr = colMap.price >= 0 ? row[colMap.price]?.trim() : "0";

      // Validate
      if (!sku || !name) {
        batchErrors.push({ row_number: i, sku: sku || "", error_message: "Missing SKU or product name" });
        failed++;
        processed++;
        continue;
      }

      const qty = parseFloat(qtyStr);
      const price = parseFloat(priceStr);

      if (isNaN(qty) || qty < 0) {
        batchErrors.push({ row_number: i, sku, error_message: `Invalid quantity: ${qtyStr}` });
        failed++;
        processed++;
        continue;
      }

      if (isNaN(price) || price < 0) {
        batchErrors.push({ row_number: i, sku, error_message: `Invalid price: ${priceStr}` });
        failed++;
        processed++;
        continue;
      }

      // Resolve category
      let categoryId: string | null = null;
      if (categoryName) {
        const key = categoryName.toLowerCase();
        if (catMap.has(key)) {
          categoryId = catMap.get(key)!;
        } else {
          // Create category
          const slug = categoryName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
          const { data: newCat } = await supabase
            .from("categories")
            .insert({ name: categoryName, slug, is_active: true, sort_order: 999 })
            .select("id")
            .single();
          if (newCat) {
            catMap.set(key, newCat.id);
            categoryId = newCat.id;
          }
        }
      }

      const productSlug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") + "-" + sku.toLowerCase().replace(/[^a-z0-9]+/g, "");

      // Check if product exists by SKU
      let productId = productBySku.get(sku.toLowerCase());
      let isNewProduct = false;

      if (!productId) {
        // Create new product
        const { data: newProd, error: prodErr } = await supabase
          .from("products")
          .insert({
            name,
            slug: productSlug,
            sku,
            category_id: categoryId,
            is_active: true,
          })
          .select("id")
          .single();

        if (prodErr || !newProd) {
          batchErrors.push({ row_number: i, sku, error_message: `Failed to create product: ${prodErr?.message || "unknown"}` });
          failed++;
          processed++;
          continue;
        }

        productId = newProd.id;
        productBySku.set(sku.toLowerCase(), productId);
        isNewProduct = true;
      } else {
        // Update existing product category if needed
        if (categoryId) {
          await supabase.from("products").update({ category_id: categoryId }).eq("id", productId);
        }
      }

      // Check if branch_product exists
      const existingBPRecord = bpByProduct.get(productId);
      if (existingBPRecord) {
        // Update existing
        const oldStock = Number(existingBPRecord.stock_quantity);
        const oldPrice = Number(existingBPRecord.selling_price);

        const { error: updateErr } = await supabase
          .from("branch_products")
          .update({
            stock_quantity: qty,
            selling_price: price,
            is_available: qty > 0,
            updated_at: new Date().toISOString(),
          })
          .eq("id", existingBPRecord.id);

        if (updateErr) {
          batchErrors.push({ row_number: i, sku, error_message: `Failed to update inventory: ${updateErr.message}` });
          failed++;
        } else {
          batchChanges.push({
            job_id: jobId,
            branch_product_id: existingBPRecord.id,
            old_stock: oldStock,
            new_stock: qty,
            old_price: oldPrice,
            new_price: price,
          });
          successful++;
        }
      } else {
        // Create new branch_product
        const { data: newBP, error: bpErr } = await supabase
          .from("branch_products")
          .insert({
            branch_id: branchId,
            product_id: productId,
            stock_quantity: qty,
            selling_price: price,
            is_available: qty > 0,
            is_active: true,
          })
          .select("id")
          .single();

        if (bpErr || !newBP) {
          batchErrors.push({ row_number: i, sku, error_message: `Failed to create inventory: ${bpErr?.message || "unknown"}` });
          failed++;
        } else {
          bpByProduct.set(productId, { id: newBP.id, stock_quantity: qty, selling_price: price });
          batchChanges.push({
            job_id: jobId,
            branch_product_id: newBP.id,
            old_stock: null,
            new_stock: qty,
            old_price: null,
            new_price: price,
          });
          successful++;
        }
      }

      processed++;

      // Flush batch
      if (batchErrors.length >= 50) {
        await supabase.from("inventory_import_errors").insert(batchErrors);
        batchErrors = [];
      }
      if (batchChanges.length >= 50) {
        await supabase.from("inventory_import_changes").insert(batchChanges);
        batchChanges = [];
      }

      // Update progress every 500 rows
      if (processed % 500 === 0 || processed === totalRows) {
        await supabase
          .from("inventory_import_jobs")
          .update({
            processed_rows: processed,
            successful_rows: successful,
            failed_rows: failed,
            skipped_rows: skipped,
          })
          .eq("id", jobId);
      }
    }

    // Flush remaining
    if (batchErrors.length) await supabase.from("inventory_import_errors").insert(batchErrors);
    if (batchChanges.length) await supabase.from("inventory_import_changes").insert(batchChanges);

    // Create notification
    const finalStatus = failed > 0 ? "completed_with_errors" : "completed";
    await supabase
      .from("inventory_import_jobs")
      .update({
        status: finalStatus,
        processed_rows: processed,
        successful_rows: successful,
        failed_rows: failed,
        skipped_rows: skipped,
        completed_at: new Date().toISOString(),
      })
      .eq("id", jobId);

    await supabase.from("admin_notifications").insert({
      type: "import",
      title: `Import ${finalStatus === "completed" ? "completed" : "completed with errors"}`,
      message: `${job.file_name}: ${successful} successful, ${failed} failed out of ${totalRows} rows`,
      related_id: jobId,
    });

    return new Response(JSON.stringify({
      success: true,
      status: finalStatus,
      processed,
      successful,
      failed,
      skipped,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  result.push(current);
  return result;
}

function resolveColumns(headers: string[]): any {
  const map: any = { sku: -1, name: -1, category: -1, qty: -1, price: -1 };
  const skuKeys = ["part_no", "sku", "partno", "item_code", "code"];
  const nameKeys = ["desc", "description", "name", "product_name", "productname", "item_name"];
  const catKeys = ["groupname", "group_name", "category", "cat", "category_name"];
  const qtyKeys = ["qty", "quantity", "stock", "stock_quantity"];
  const priceKeys = ["price1", "price", "selling_price", "unit_price"];

  headers.forEach((h, i) => {
    const clean = h.trim().toLowerCase();
    if (skuKeys.includes(clean) && map.sku < 0) map.sku = i;
    if (nameKeys.includes(clean) && map.name < 0) map.name = i;
    if (catKeys.includes(clean) && map.category < 0) map.category = i;
    if (qtyKeys.includes(clean) && map.qty < 0) map.qty = i;
    if (priceKeys.includes(clean) && map.price < 0) map.price = i;
  });

  return map;
}
