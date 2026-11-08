export function sidebarParts(root) {
  let rail = root?.id === "sidebar" ? root : undefined;
  let stack = root?.id === "sidebar-lists" ? root : undefined;
  for (const child of root?.children ?? []) {
    const found = sidebarParts(child);
    rail ??= found.rail;
    stack ??= found.stack;
    if (rail && stack) break;
  }
  return { rail, stack };
}
