import { SHX8800PRO } from '../core/constants/memory-map'

export interface BootImageResult {
  dataUrl: string
  rgb565: number[]
}

export async function loadBootImage(file: File): Promise<BootImageResult> {
  const bitmap = await createImageBitmap(file)
  const canvas = document.createElement('canvas')
  canvas.width = SHX8800PRO.bootImageWidth
  canvas.height = SHX8800PRO.bootImageHeight
  const context = canvas.getContext('2d')
  if (!context) throw new Error('Canvas 初始化失败')
  context.fillStyle = '#000'
  context.fillRect(0, 0, canvas.width, canvas.height)
  const ratio = Math.max(canvas.width / bitmap.width, canvas.height / bitmap.height)
  const width = bitmap.width * ratio
  const height = bitmap.height * ratio
  context.drawImage(bitmap, (canvas.width - width) / 2, (canvas.height - height) / 2, width, height)
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data
  const rgb565: number[] = []
  for (let index = 0; index < pixels.length; index += 4) {
    const red = pixels[index] >> 3
    const green = pixels[index + 1] >> 2
    const blue = pixels[index + 2] >> 3
    const value = (red << 11) | (green << 5) | blue
    rgb565.push(value & 0xff, (value >> 8) & 0xff)
  }
  return {
    dataUrl: canvas.toDataURL('image/png'),
    rgb565,
  }
}
