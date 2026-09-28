export function productImages(main: string | null | undefined, additional: unknown): string[] {
  return [...new Set([main, ...(Array.isArray(additional) ? additional : [])]
    .filter((url): url is string => typeof url === 'string' && !!url.trim())
    .map(url => url.trim()))]
}

export function validateProductImages(images: string[]): string[] {
  const urls = productImages(null, images)
  for (const url of urls) {
    try {
      if (!['http:', 'https:'].includes(new URL(url).protocol)) throw new Error()
    } catch {
      throw new Error('Enter a valid public HTTP or HTTPS URL for each image.')
    }
  }
  return urls
}
