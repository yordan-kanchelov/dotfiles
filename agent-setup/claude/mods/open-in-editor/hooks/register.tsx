import type { Register } from 'claude-code'

import { fromHref, linkify } from './links'

export const register: Register = on => {
  // Files found so far; replies redraw on every scroll. Misses are re-checked, as the file may appear later.
  const found = new Set<string>()

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const cwd = await $.session.cwd()
    const { text, hrefs } = await linkify(e.props.text, async path => {
      const abs = path.startsWith('/') ? path : `${cwd}/${path}`
      if (!found.has(abs) && (await $.fs.stat(abs).catch(() => undefined))?.kind === 'file') found.add(abs)
      return found.has(abs) ? abs : undefined
    })
    if (hrefs.length === 0) return next(e)

    const { Box, Markdown, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="row">
        <Text>{e.props.isFirstOfReply ? '● ' : '  '}</Text>
        <Box flexGrow={1}>
          <Markdown
            key="reply"
            text={text}
            pressableLinks={hrefs}
            onLinkPress={async link => {
              const target = fromHref(link.href)
              if (!target) return
              const dir = target.path.slice(0, target.path.lastIndexOf('/')) || '/'
              const git = await $.process.run(['git', '-C', dir, 'rev-parse', '--show-toplevel'])
              const root = git.exitCode === 0 ? git.stdout.trim() : await $.session.root()
              const file = target.line ? `${target.path}:${target.line}` : target.path
              const opened = await $.process.run(['code', root, '-g', file]).catch(() => undefined)
              if (opened?.exitCode !== 0) $.ui.toast(`open-in-editor: could not run code for ${file}`)
            }}
          />
        </Box>
      </Box>
    )
  })
}
