const SPAN = /(?<!`)`([^`\s:]+)(?::(\d+))?`(?!`)/g
const TAKEN = /\[[^\]\n]*\](?:\([^)\n]*\)|\[[^\]\n]*\])|<[a-z][\w+.-]*:[^>\s]*>|(``+)(?!`)[^\n]*?(?<!`)\1(?!`)/gi
const OPEN = /^ {0,3}(`{3,}|~{3,})/
const PATHLIKE = /\/|\.\w+$/

export type Target = { path: string; line?: number }

const blank = (s: string) => s.replace(/[^\n]/g, ' ')

const prose = (text: string): string => {
  let fence: string | undefined
  const lines = text.split('\n').map(line => {
    if (fence) {
      const close = new RegExp(`^ {0,3}${fence[0]}{${fence.length},}\\s*$`)
      if (close.test(line)) fence = undefined
      return blank(line)
    }
    fence = OPEN.exec(line)?.[1]
    return fence ? blank(line) : line
  })
  return lines.join('\n').replace(TAKEN, blank)
}

export const toHref = (abs: string, line?: number): string =>
  'file://' + encodeURI(abs).replace(/[()#?]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase()) + (line ? `#L${line}` : '')

export const fromHref = (href: string): Target | undefined => {
  if (!href.startsWith('file://')) return undefined
  const url = new URL(href)
  const line = /^#L(\d+)$/.exec(url.hash)?.[1]
  return { path: decodeURIComponent(url.pathname), line: line ? Number(line) : undefined }
}

export const linkify = async (text: string, resolve: (path: string) => Promise<string | undefined>) => {
  let out = ''
  let at = 0
  const hrefs: string[] = []
  for (const m of prose(text).matchAll(SPAN)) {
    const abs = PATHLIKE.test(m[1]) ? await resolve(m[1]) : undefined
    if (!abs) continue
    const href = toHref(abs, m[2] ? Number(m[2]) : undefined)
    out += text.slice(at, m.index) + `[${m[0]}](${href})`
    at = m.index + m[0].length
    hrefs.push(href)
  }
  return { text: out + text.slice(at), hrefs }
}
