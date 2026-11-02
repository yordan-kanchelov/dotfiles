import { expect, test } from 'claude-code/testing'

const REPLY = {
  plugin: 'open-in-editor',
  component: 'AssistantMessage',
  props: {
    text: 'See `agent-setup/README.md` and `hooks/a.ts:12`, not `missing.md` or `npm test`.\n\n```\n`agent-setup/README.md`\n```',
    isFirstOfReply: true,
  },
} as const

const FILES = new Set(['/repo/agent-setup/README.md', '/repo/hooks/a.ts'])

test('existing paths become links that open the git root and the file in code', async ($, on) => {
  const ran: (readonly string[])[] = []
  on('session.cwd', () => ({ value: '/repo' }))
  on('session.root', () => ({ value: '/repo' }))
  on('fs.stat', (_, e) =>
    FILES.has(e.path)
      ? { value: { kind: 'file', size: 1, mtimeMs: 0, isLink: false } }
      : { value: { kind: 'other', size: 0, mtimeMs: 0, isLink: false } },
  )
  on('process.run', (_, e) => {
    ran.push(e.argv)
    const stdout = e.argv[0] === 'git' ? '/repo\n' : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  const ui = await $.ui.mount({ ...REPLY, surface: 'terminal' })
  const md = await ui.find({ type: 'Markdown', key: 'reply' })
  expect(md?.text).toContain('[`agent-setup/README.md`](file:///repo/agent-setup/README.md)')
  expect(md?.text).toContain('[`hooks/a.ts:12`](file:///repo/hooks/a.ts#L12)')
  expect(md?.text).toContain('`missing.md` or `npm test`')
  expect(md?.text).toContain('```\n`agent-setup/README.md`\n```')

  await ui.press({ key: 'reply', link: { href: 'file:///repo/hooks/a.ts#L12' } })
  expect(ran).toContainEqual(['code', '/repo', '-g', '/repo/hooks/a.ts:12'])
  await ui.unmount()
})

test('fences, existing links and double-backtick spans are left alone', async ($, on) => {
  on('session.cwd', () => ({ value: '/repo' }))
  on('fs.stat', () => ({ value: { kind: 'file', size: 1, mtimeMs: 0, isLink: false } }))

  const text = [
    'Open `a.md`, [see `b.md`](https://example.org) and ``c.md``.',
    '[ref `f.md`][docs] and ``an `g.md` span``.',
    '  ```',
    '  `d.md`',
    '  ```',
    '````',
    '```',
    '`e.md`',
    '````',
  ].join('\n')
  const ui = await $.ui.mount({ ...REPLY, props: { text, isFirstOfReply: false }, surface: 'terminal' })
  const md = await ui.find({ type: 'Markdown', key: 'reply' })
  expect(md?.text).toBe(text.replace('`a.md`', '[`a.md`](file:///repo/a.md)'))
  await ui.unmount()
})

test('a reply without file paths is left to the engine', async ($, on) => {
  on('session.cwd', () => ({ value: '/repo' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...REPLY, props: { text: 'No paths here.', isFirstOfReply: true }, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  await ui.unmount()
})
