<script setup lang="ts">
const props = defineProps<{ modelValue: string[] }>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()
function update(index: number, event: Event) {
  const images = [...props.modelValue]
  images[index] = (event.target as HTMLInputElement).value
  emit('update:modelValue', images)
}
function preview(url: string) {
  try { return ['http:', 'https:'].includes(new URL(url).protocol) ? url : '' } catch { return '' }
}
</script>

<template>
  <div class="space-y-3">
    <p class="text-sm font-medium text-ink-600">Product Images</p>
    <p class="text-xs text-ink-400">Enter public image URLs. The first image is the main image shown in the shop.</p>
    <div v-for="(url, index) in modelValue" :key="index" class="flex items-start gap-2">
      <img v-if="preview(url)" :src="preview(url)" :alt="`Image ${index + 1} preview`" class="w-16 h-16 rounded-lg object-contain bg-ink-50" />
      <label class="flex-1 min-w-0 text-sm text-ink-600">
        {{ index === 0 ? 'Main Image URL' : `Image ${index + 1} URL` }}
        <input :value="url" type="url" pattern="https?://.*" placeholder="https://example.com/product.jpg" class="input mt-1" @input="update(index, $event)" />
      </label>
      <button type="button" class="text-sm text-red-600 mt-7" :aria-label="`Remove image ${index + 1}`" @click="emit('update:modelValue', modelValue.filter((_, i) => i !== index))">Remove</button>
    </div>
    <button type="button" class="btn-outline text-sm" @click="emit('update:modelValue', [...modelValue, ''])">+ Add Image</button>
  </div>
</template>
