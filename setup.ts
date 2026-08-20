#!/usr/bin/env node --experimental-strip-types
import { fileURLToPath } from 'url';
import { basename, dirname, join, resolve } from 'path';
import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync, symlinkSync, readlinkSync, lstatSync, readdirSync } from 'fs';
import { homedir, platform, userInfo } from 'os';
import { program } from 'commander';
import chalk from 'chalk';
import inquirer from 'inquirer';
import ora from 'ora';
import { execa } from 'execa';
import which from 'which';
import fsExtra from 'fs-extra';
import YAML from 'yaml';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const DOTFILES_DIR = __dirname;
const HOME = homedir();
const BACKUP_DIR = join(HOME, '.dotfiles_backup', new Date().toISOString().replace(/:/g, '-'));
const IS_CI = Boolean(process.env.CI || process.env.GITHUB_ACTIONS);
const IS_MACOS = platform() === 'darwin';
const IS_LINUX = platform() === 'linux';
// A launcher and a global hotkey only mean anything on a graphical session, so
// desktop setup stays out of the way on servers, in CI, and over plain SSH.
const HAS_DESKTOP = Boolean(process.env.XDG_CURRENT_DESKTOP);

// Type definitions
interface SetupOptions {
  nonInteractive?: boolean;
  forceOverwrite?: boolean;
  append?: boolean;
  skipPackages?: boolean;
  interactive?: boolean;
  verify?: boolean;
  desktop?: boolean;
}

type LogType = 'info' | 'success' | 'warning' | 'error';

// Parse command line options
program
  .option('--non-interactive', 'Run without prompts')
  .option('--force-overwrite', 'Overwrite existing files without prompting')
  .option('--append', 'Append to existing config files instead of symlinking')
  .option('--skip-packages', 'Skip package installation')
  .option('--verify', 'Verify managed symlinks and secrets file, then exit')
  .option('--desktop', 'Run only the Linux desktop/GUI setup, then exit')
  .option('-i, --interactive', 'Run in interactive mode (default)')
  .parse();

const options: SetupOptions = program.opts();

// Adjust options for CI
if (IS_CI) {
  console.log(chalk.blue('CI environment detected. Adjusting settings...'));
  options.nonInteractive = true;
  // Don't override skipPackages if explicitly set via command line
  if (!process.argv.includes('--skip-packages')) {
    options.skipPackages = false;
  }
}

// Helper functions
function log(message: string, type: LogType = 'info'): void {
  const colors = {
    info: chalk.blue,
    success: chalk.green,
    warning: chalk.yellow,
    error: chalk.red
  };
  console.log(colors[type](message));
}

async function commandExists(command: string): Promise<boolean> {
  try {
    await which(command);
    return true;
  } catch {
    return false;
  }
}

async function backupFile(filePath: string): Promise<void> {
  if (!existsSync(filePath)) return;

  const relativePath = filePath.startsWith(HOME) ? filePath.slice(HOME.length + 1) : filePath;
  const backupPath = join(BACKUP_DIR, relativePath.replace(/[\/\\]/g, '_') + '.bak');
  const backupDir = dirname(backupPath);

  mkdirSync(backupDir, { recursive: true });
  await fsExtra.copy(filePath, backupPath);
  log(`Backed up ${filePath} to ${backupPath}`, 'info');
}

async function promptUser(message: string, defaultChoice: boolean = false): Promise<boolean> {
  if (options.nonInteractive) {
    return defaultChoice;
  }

  const { answer } = await inquirer.prompt<{ answer: boolean }>([{
    type: 'confirm',
    name: 'answer',
    message,
    default: defaultChoice
  }]);

  return answer;
}

async function handleConfigFile(sourceFile: string, targetFile: string): Promise<void> {
  // Append mode
  if (options.append) {
    if (!existsSync(targetFile)) {
      await fsExtra.copy(sourceFile, targetFile);
      log(`Created new file: ${targetFile}`, 'success');
    } else {
      await backupFile(targetFile);
      const content = readFileSync(sourceFile, 'utf8');
      const appendContent = `\n# Appended by dotfiles setup on ${new Date().toISOString()}\n${content}`;
      await fsExtra.appendFile(targetFile, appendContent);
      log(`Appended config to: ${targetFile}`, 'success');
    }
    return;
  }

  // If target doesn't exist, create symlink
  if (!existsSync(targetFile)) {
    symlinkSync(sourceFile, targetFile);
    log(`Created symlink: ${targetFile} -> ${sourceFile}`, 'success');
    return;
  }

  // If already our symlink, skip
  try {
    if (lstatSync(targetFile).isSymbolicLink() && readlinkSync(targetFile) === sourceFile) {
      log(`Symlink already exists: ${targetFile} -> ${sourceFile}`, 'success');
      return;
    }
  } catch {
    // Ignore error
  }

  // Handle existing file
  log(`File already exists: ${targetFile}`, 'warning');

  if (options.forceOverwrite) {
    await backupFile(targetFile);
    await fsExtra.remove(targetFile);
    symlinkSync(sourceFile, targetFile);
    log(`Overwrote: ${targetFile} -> ${sourceFile}`, 'success');
    return;
  }

  if (!options.nonInteractive) {
    const { action } = await inquirer.prompt<{ action: 'overwrite' | 'append' | 'skip' }>([{
      type: 'list',
      name: 'action',
      message: `What would you like to do with ${targetFile}?`,
      choices: [
        { name: 'Overwrite (backup will be created)', value: 'overwrite' },
        { name: 'Append to existing file', value: 'append' },
        { name: 'Skip this file', value: 'skip' }
      ],
      default: 'overwrite'
    }]);

    switch (action) {
      case 'append':
        await backupFile(targetFile);
        const content = readFileSync(sourceFile, 'utf8');
        const appendContent = `\n# Appended by dotfiles setup on ${new Date().toISOString()}\n${content}`;
        await fsExtra.appendFile(targetFile, appendContent);
        log(`Appended config to: ${targetFile}`, 'success');
        break;
      case 'skip':
        log(`Skipped: ${targetFile}`, 'warning');
        break;
      default:
        await backupFile(targetFile);
        await fsExtra.remove(targetFile);
        symlinkSync(sourceFile, targetFile);
        log(`Overwrote: ${targetFile} -> ${sourceFile}`, 'success');
    }
  } else {
    log(`Skipped: ${targetFile} (use --force-overwrite or --append to modify)`, 'warning');
  }
}

async function createSymlink(sourceFile: string, targetFile: string): Promise<void> {
  if (!existsSync(sourceFile)) {
    log(`Source file not found: ${sourceFile} - skipping`, 'warning');
    return;
  }

  // Special handling for shell config files (macOS uses zsh)
  const configFiles = ['.zshrc'];
  if (configFiles.some(file => targetFile.endsWith(file))) {
    await handleConfigFile(sourceFile, targetFile);
  } else {
    // Standard symlink behavior
    let targetExists = false;
    try {
      lstatSync(targetFile);
      targetExists = true;
    } catch {
      // File doesn't exist or broken symlink
      targetExists = false;
    }

    if (targetExists) {
      const shouldOverwrite = options.forceOverwrite || await promptUser(`Overwrite ${targetFile}?`, false);
      if (shouldOverwrite) {
        await backupFile(targetFile);
        await fsExtra.remove(targetFile);
        symlinkSync(sourceFile, targetFile);
        log(`Created symlink: ${targetFile} -> ${sourceFile}`, 'success');
      } else {
        log(`Skipped: ${targetFile}`, 'warning');
      }
    } else {
      symlinkSync(sourceFile, targetFile);
      log(`Created symlink: ${targetFile} -> ${sourceFile}`, 'success');
    }
  }
}

function parseBrewPackages(filePath: string): { formulae: string[]; casks: string[] } {
  if (!existsSync(filePath)) return { formulae: [], casks: [] };
  const data = YAML.parse(readFileSync(filePath, 'utf8'));
  const formulae = Object.values(data?.formulae ?? {}).flat() as string[];
  return { formulae, casks: data?.casks ?? [] };
}

function parseAptPackages(filePath: string): string[] {
  if (!existsSync(filePath)) return [];
  const data = YAML.parse(readFileSync(filePath, 'utf8'));
  const packages = Object.values(data ?? {})
    .filter(Array.isArray)
    .flat()
    .filter((v): v is string => typeof v === 'string');
  return [...new Set(packages)];
}

// Formulae brew must not install on Linux. Checked against the homebrew-core
// API, the first three have no Linux bottle: tart runs Apple Silicon VMs, and
// apt already covers telnet and pipx. ollama does have one, but it is CPU-only
// — see installOllamaLinux, which fetches the upstream build instead.
const MACOS_ONLY_FORMULAE = new Set(['tart', 'telnet', 'pipx', 'ollama']);

async function installBrewPackages(): Promise<void> {
  if (!await commandExists('brew')) {
    if (IS_LINUX) {
      // Linux keeps apt plus the per-tool installers as a fallback, so a
      // missing brew is a downgrade, not a dead end.
      log('Homebrew not found, skipping brew packages', 'warning');
      return;
    }
    log('Error: Homebrew not found. Please run bootstrap.sh first.', 'error');
    process.exit(1);
  }

  log('Installing required packages with Homebrew...', 'info');

  const parsed = parseBrewPackages(join(DOTFILES_DIR, 'brew_packages.yml'));
  const formulae = IS_LINUX
    ? parsed.formulae.filter(pkg => !MACOS_ONLY_FORMULAE.has(pkg))
    : parsed.formulae;
  // Homebrew Cask is macOS-only; on Linux those apps come from apt, flatpak
  // or the desktop step.
  const casks = IS_LINUX ? [] : parsed.casks;
  const failedPackages: string[] = [];

  for (const pkg of formulae) {
    const spinner = ora(`Installing ${pkg}...`).start();
    try {
      await execa('brew', ['install', pkg], {
        timeout: IS_CI ? 300000 : undefined
      });
      spinner.succeed(`Successfully installed ${pkg}`);
    } catch (error) {
      spinner.fail(`Failed to install ${pkg}`);
      failedPackages.push(pkg);
    }
  }

  for (const pkg of casks) {
    const spinner = ora(`Installing cask ${pkg}...`).start();
    try {
      await execa('brew', ['install', '--cask', pkg], {
        timeout: IS_CI ? 300000 : undefined
      });
      spinner.succeed(`Successfully installed cask ${pkg}`);
    } catch (error) {
      spinner.fail(`Failed to install cask ${pkg}`);
      failedPackages.push(pkg);
    }
  }

  if (failedPackages.length > 0) {
    log(`Failed to install packages: ${failedPackages.join(', ')}`, 'warning');
  }
}

// Every sudo/installer call below runs with stdio piped, so a password prompt
// or an installer question is invisible and the run appears to hang forever.
// Ask for the sudo password once, up front, with the prompt actually visible.
let sudoKeepAlive: NodeJS.Timeout | null = null;

async function ensureSudo(): Promise<boolean> {
  if (!IS_LINUX || IS_CI) return true;

  // Already have a valid timestamp? Nothing to do.
  try {
    await execa('sudo', ['-n', 'true']);
    startSudoKeepAlive();
    return true;
  } catch {
    // Needs a password below.
  }

  log('Some packages need sudo. Enter your password once and the rest runs unattended:', 'info');
  try {
    // stdio: 'inherit' is the whole point — the prompt reaches your terminal.
    await execa('sudo', ['-v'], { stdio: 'inherit' });
    startSudoKeepAlive();
    return true;
  } catch {
    log('sudo authentication failed; skipping steps that require root', 'warning');
    return false;
  }
}

// Long installs can outlive sudo's 15-minute timestamp; refresh it while we work.
function startSudoKeepAlive(): void {
  if (sudoKeepAlive) return;
  sudoKeepAlive = setInterval(() => {
    execa('sudo', ['-n', '-v']).catch(() => {});
  }, 60000);
  sudoKeepAlive.unref();
}

function stopSudoKeepAlive(): void {
  if (sudoKeepAlive) {
    clearInterval(sudoKeepAlive);
    sudoKeepAlive = null;
  }
}

async function installAptPackages(): Promise<void> {
  if (!await commandExists('apt-get')) {
    log('Error: apt-get not found. Skipping APT package installation.', 'error');
    return;
  }

  if (!await ensureSudo()) return;

  log('Installing required packages with APT...', 'info');

  const spinner = ora('Updating package lists...').start();
  try {
    await execa('sudo', ['-n', 'apt-get', 'update', '-y'], {
      timeout: IS_CI ? 300000 : undefined
    });
    spinner.succeed('Package lists updated');
  } catch (error) {
    spinner.fail('Failed to update package lists');
    log(error instanceof Error ? error.message : 'Unknown error', 'error');
    return;
  }

  const packages = parseAptPackages(join(DOTFILES_DIR, 'apt_packages.yml'));
  const failedPackages: string[] = [];
  const BATCH_SIZE = 5;

  for (let i = 0; i < packages.length; i += BATCH_SIZE) {
    const batch = packages.slice(i, i + BATCH_SIZE);
    const batchSpinner = ora(`Installing batch: ${batch.join(', ')}...`).start();
    try {
      await execa('sudo', ['-n', 'apt-get', 'install', '-y', ...batch], {
        timeout: IS_CI ? 300000 : undefined
      });
      batchSpinner.succeed(`Installed: ${batch.join(', ')}`);
    } catch {
      batchSpinner.warn(`Batch failed, trying individually: ${batch.join(', ')}`);
      for (const pkg of batch) {
        const pkgSpinner = ora(`Installing ${pkg}...`).start();
        try {
          await execa('sudo', ['-n', 'apt-get', 'install', '-y', pkg], {
            timeout: IS_CI ? 300000 : undefined
          });
          pkgSpinner.succeed(`Successfully installed ${pkg}`);
        } catch {
          pkgSpinner.fail(`Failed to install ${pkg}`);
          failedPackages.push(pkg);
        }
      }
    }
  }

  if (failedPackages.length > 0) {
    log(`Failed to install packages: ${failedPackages.join(', ')}`, 'warning');
  }
}

const LINUXBREW_PREFIX = '/home/linuxbrew/.linuxbrew';

// Homebrew gives Linux current builds of nearly everything in this repo; apt
// on 24.04 is years behind (neovim 0.9.5 vs 0.12, fd 9 vs 10, eza 0.18 vs 0.23).
async function installHomebrewLinux(): Promise<void> {
  if (await commandExists('brew')) {
    log('Homebrew is already installed', 'success');
    return;
  }

  if (!await ensureSudo()) {
    log('No sudo access, skipping Homebrew installation', 'warning');
    return;
  }

  const spinner = ora('Installing Homebrew (this takes a few minutes)...').start();
  try {
    // NONINTERACTIVE stops the installer blocking on a RETURN prompt that is
    // invisible here. It needs sudo for /home/linuxbrew — a HOME-local prefix
    // would miss every bottle and compile the lot from source instead.
    await execa('bash', ['-c',
      'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"']);
    spinner.succeed('Homebrew installed');
  } catch (error) {
    spinner.fail('Failed to install Homebrew');
    log(error instanceof Error ? error.message : 'Unknown error', 'error');
    return;
  }

  // shellenv only reaches future logins; this process needs brew on PATH now.
  process.env.PATH = `${LINUXBREW_PREFIX}/bin:${LINUXBREW_PREFIX}/sbin:${process.env.PATH}`;
}

async function createLinuxCompatSymlinks(): Promise<void> {
  // On Debian/Ubuntu, bat installs as "batcat" and fd installs as "fdfind".
  // Our zsh config references "bat" and "fd" directly, so create compatibility symlinks.
  const localBin = join(HOME, '.local/bin');
  mkdirSync(localBin, { recursive: true });

  const aliases: [string, string][] = [
    ['batcat', 'bat'],
    ['fdfind', 'fd'],
  ];

  for (const [installed, alias] of aliases) {
    // Homebrew ships a real bat/fd, but .zprofile prepends ~/.local/bin after
    // brew's shellenv runs — so leaving our shim in place would pin the older
    // apt build ahead of it.
    if (existsSync(join(LINUXBREW_PREFIX, 'bin', alias))) {
      const shim = join(localBin, alias);
      if (lstatSync(shim, { throwIfNoEntry: false })?.isSymbolicLink()) {
        await fsExtra.remove(shim);
        log(`Removed ${alias} shim — Homebrew provides the real binary`, 'success');
      }
      continue;
    }

    if (await commandExists(installed) && !await commandExists(alias)) {
      const installedPath = await which(installed);
      const aliasPath = join(localBin, alias);
      try {
        symlinkSync(installedPath, aliasPath);
        log(`Created compatibility symlink: ${aliasPath} -> ${installedPath}`, 'success');
      } catch (error) {
        // Symlink may already exist from a previous run
        if ((error as NodeJS.ErrnoException).code !== 'EEXIST') {
          log(`Failed to create symlink for ${alias}: ${error instanceof Error ? error.message : 'Unknown error'}`, 'warning');
        }
      }
    }
  }
}

// Debian/Ubuntu create accounts with bash, so every zsh config this repo links
// sits inert until the login shell itself changes.
async function setDefaultShellZsh(): Promise<void> {
  if (IS_CI) return;

  let zshPath: string;
  try {
    zshPath = await which('zsh');
  } catch {
    log('zsh not found, skipping default shell change', 'warning');
    return;
  }

  // The login shell lives in /etc/passwd. $SHELL only describes the current
  // process, and reads as bash inside any bash subshell regardless of it.
  let current: string;
  try {
    const { stdout } = await execa('getent', ['passwd', userInfo().username]);
    current = stdout.trim().split(':').pop() ?? '';
  } catch {
    log('Could not read the current login shell, skipping', 'warning');
    return;
  }

  if (current === zshPath) {
    log(`Default shell is already ${zshPath}`, 'success');
    return;
  }

  // chsh rejects any shell missing from /etc/shells.
  const shells = existsSync('/etc/shells') ? readFileSync('/etc/shells', 'utf8').split('\n') : [];
  if (!shells.includes(zshPath)) {
    try {
      await execa('bash', ['-c', `echo ${zshPath} | sudo -n tee -a /etc/shells > /dev/null`]);
      log(`Added ${zshPath} to /etc/shells`, 'success');
    } catch {
      log(`Could not add ${zshPath} to /etc/shells, skipping shell change`, 'warning');
      return;
    }
  }

  const spinner = ora(`Setting default shell to ${zshPath}...`).start();
  try {
    await execa('sudo', ['-n', 'chsh', '-s', zshPath, userInfo().username]);
    spinner.succeed(`Default shell set to ${zshPath} — takes effect at next login`);
  } catch (error) {
    spinner.fail('Failed to change the default shell');
    log(`Run it yourself with: chsh -s ${zshPath}`, 'info');
  }
}

async function installSpecialPackagesLinux(): Promise<void> {
  log('Installing tools that require special installation methods...', 'info');

  // lazygit and gh shell out to sudo below; make sure the password prompt
  // happens here, visibly, rather than silently inside a piped subprocess.
  const hasSudo = await ensureSudo();

  // sheldon (zsh plugin manager)
  if (!await commandExists('sheldon')) {
    const spinner = ora('Installing sheldon...').start();
    try {
      await execa('bash', ['-c', 'curl --proto "=https" -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin'], {
        timeout: IS_CI ? 120000 : undefined
      });
      spinner.succeed('sheldon installed');
    } catch (error) {
      spinner.fail('Failed to install sheldon');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  } else {
    log('sheldon is already installed', 'success');
  }

  // fnm (Node version manager) - usually handled by bootstrap.sh, but check just in case
  if (!await commandExists('fnm')) {
    const spinner = ora('Installing fnm...').start();
    try {
      await execa('bash', ['-c', 'curl -fsSL https://fnm.vercel.app/install | bash']);
      spinner.succeed('fnm installed');
    } catch (error) {
      spinner.fail('Failed to install fnm');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  } else {
    log('fnm is already installed', 'success');
  }

  // starship prompt
  if (!await commandExists('starship')) {
    const spinner = ora('Installing starship...').start();
    try {
      await execa('bash', ['-c', 'curl -sS https://starship.rs/install.sh | sh -s -- -y']);
      spinner.succeed('starship installed');
    } catch (error) {
      spinner.fail('Failed to install starship');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  } else {
    log('starship is already installed', 'success');
  }

  // atuin (shell history)
  if (!await commandExists('atuin')) {
    const spinner = ora('Installing atuin...').start();
    try {
      // --non-interactive: the installer otherwise reads from /dev/tty to ask
      // about history import and sync signup, which hangs here forever because
      // its stdout is piped and the question is never displayed.
      await execa('bash', ['-c', 'curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive']);
      spinner.succeed('atuin installed');
    } catch (error) {
      spinner.fail('Failed to install atuin');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  } else {
    log('atuin is already installed', 'success');
  }

  // lazygit
  if (!await commandExists('lazygit')) {
    const spinner = ora('Installing lazygit...').start();
    try {
      const { stdout: version } = await execa('bash', ['-c', 'curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep \'"tag_name":\' | sed -E \'s/.*"v([^"]+)".*/\\1/\'']);
      const { stdout: unameMachine } = await execa('uname', ['-m']);
      const archMap: Record<string, string> = { x86_64: 'x86_64', aarch64: 'arm64', arm64: 'arm64' };
      const arch = archMap[unameMachine] ?? unameMachine;
      // Install into ~/.local/bin like sheldon/bat/fd rather than /usr/local/bin,
      // so this no longer depends on sudo at all.
      const localBin = join(HOME, '.local/bin');
      mkdirSync(localBin, { recursive: true });
      await execa('bash', ['-c', `curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_${arch}.tar.gz" && tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && install -m755 /tmp/lazygit ${localBin}/lazygit && rm /tmp/lazygit.tar.gz /tmp/lazygit`]);
      spinner.succeed('lazygit installed');
    } catch (error) {
      spinner.fail('Failed to install lazygit');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  } else {
    log('lazygit is already installed', 'success');
  }

  // fzf: Ubuntu 24.04 ships 0.44, which predates the `fzf --zsh` flag added in
  // 0.48 that .zshrc.core uses. ~/.local/bin precedes /usr/bin in .zprofile,
  // so a current build dropped there shadows the distro one.
  const fzfHasZshFlag = await execa('fzf', ['--zsh']).then(() => true).catch(() => false);
  if (fzfHasZshFlag) {
    log('fzf already supports --zsh', 'success');
  } else {
    const spinner = ora('Installing current fzf (distro build predates --zsh)...').start();
    try {
      const { stdout: json } = await execa('curl', ['-fsSL',
        'https://api.github.com/repos/junegunn/fzf/releases/latest']);
      const tag = JSON.parse(json).tag_name as string;
      const { stdout: unameMachine } = await execa('uname', ['-m']);
      const archMap: Record<string, string> = { x86_64: 'amd64', aarch64: 'arm64', arm64: 'arm64' };
      const arch = archMap[unameMachine] ?? unameMachine;
      // Tags carry a leading "v" that the asset names drop.
      const tarball = `fzf-${tag.replace(/^v/, '')}-linux_${arch}.tar.gz`;
      const localBin = join(HOME, '.local/bin');
      mkdirSync(localBin, { recursive: true });
      const tmp = join('/tmp', tarball);
      await execa('curl', ['-fLo', tmp,
        `https://github.com/junegunn/fzf/releases/download/${tag}/${tarball}`]);
      await execa('tar', ['xf', tmp, '-C', localBin, 'fzf']);
      await fsExtra.remove(tmp);
      spinner.succeed(`fzf ${tag} installed to ~/.local/bin`);
    } catch (error) {
      spinner.fail('Failed to install fzf');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  }

  // gh (GitHub CLI)
  if (!await commandExists('gh')) {
    if (!await commandExists('apt-get')) {
      log('apt-get not found, skipping GitHub CLI installation', 'warning');
    } else if (!hasSudo) {
      log('No sudo access, skipping GitHub CLI installation', 'warning');
    } else {
      const spinner = ora('Installing GitHub CLI...').start();
      try {
        await execa('bash', ['-c', [
          'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo -n dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg',
          'sudo -n chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg',
          'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo -n tee /etc/apt/sources.list.d/github-cli.list > /dev/null',
          'sudo -n apt-get update -y',
          'sudo -n apt-get install -y gh'
        ].join(' && ')]);
        spinner.succeed('GitHub CLI installed');
      } catch (error) {
        spinner.fail('Failed to install GitHub CLI');
        log(error instanceof Error ? error.message : 'Unknown error', 'error');
      }
    }
  } else {
    log('gh is already installed', 'success');
  }

  await installOllamaLinux();
}

// Homebrew's Linux bottle ships only libggml-cpu-*.so, so brew's ollama runs
// 27B models at ~5 tok/s on CPU even with a 3090 idle next to it. The upstream
// tarball carries the CUDA runners; ollama is in MACOS_ONLY_FORMULAE so brew
// never installs the crippled one here.
async function installOllamaLinux(): Promise<void> {
  const prefix = join(HOME, '.local/ollama');
  const binary = join(prefix, 'bin/ollama');
  const localBin = join(HOME, '.local/bin');

  if (!existsSync(binary)) {
    // tar needs the zstd binary to decompress upstream's .tar.zst assets.
    if (!await commandExists('zstd')) {
      log('zstd not found, skipping ollama (apt install zstd, then re-run)', 'warning');
      return;
    }

    const spinner = ora('Installing ollama (~1.4GB, bundles CUDA runners)...').start();
    try {
      const { stdout: json } = await execa('curl', ['-fsSL',
        'https://api.github.com/repos/ollama/ollama/releases/latest']);
      const tag = JSON.parse(json).tag_name as string;
      const { stdout: unameMachine } = await execa('uname', ['-m']);
      const archMap: Record<string, string> = { x86_64: 'amd64', aarch64: 'arm64', arm64: 'arm64' };
      const arch = archMap[unameMachine] ?? unameMachine;
      const tmp = join('/tmp', `ollama-linux-${arch}.tar.zst`);
      await execa('curl', ['-fLo', tmp,
        `https://github.com/ollama/ollama/releases/download/${tag}/ollama-linux-${arch}.tar.zst`]);
      mkdirSync(prefix, { recursive: true });
      await execa('tar', ['--zstd', '-xf', tmp, '-C', prefix]);
      await fsExtra.remove(tmp);
      spinner.succeed(`ollama ${tag} installed to ~/.local/ollama`);
    } catch (error) {
      spinner.fail('Failed to install ollama');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
      return;
    }
  } else {
    log('ollama is already installed', 'success');
  }

  // The bundle keeps its libs beside the binary, so ~/.local/bin gets a link
  // rather than a copy. .zprofile already has ~/.local/bin on PATH.
  mkdirSync(localBin, { recursive: true });
  await createSymlink(binary, join(localBin, 'ollama'));

  if (!await commandExists('systemctl')) return;

  // A user unit, not a system one: no sudo, and the daemon follows the login
  // session like every other tool this script installs.
  const unit = join(HOME, '.config/systemd/user/ollama.service');
  if (!existsSync(unit)) {
    mkdirSync(dirname(unit), { recursive: true });
    writeFileSync(unit, [
      '[Unit]',
      'Description=Ollama',
      'After=network-online.target',
      '',
      '[Service]',
      `ExecStart=${binary} serve`,
      'Restart=always',
      'RestartSec=3',
      '',
      '[Install]',
      'WantedBy=default.target',
      ''
    ].join('\n'));
    log(`Created ${unit}`, 'success');
  }

  try {
    await execa('systemctl', ['--user', 'daemon-reload']);
    await execa('systemctl', ['--user', 'enable', '--now', 'ollama.service']);
    log('ollama service running (systemctl --user status ollama)', 'success');
  } catch (error) {
    log(`Could not start ollama service: ${error instanceof Error ? error.message : 'Unknown error'}`, 'warning');
  }
}

async function gsettingsGet(args: string[]): Promise<string> {
  const { stdout } = await execa('gsettings', ['get', ...args]);
  return stdout.trim();
}

// Cinnamon keeps custom shortcuts as custom0/custom1/... under a relocatable
// schema, plus a separate list naming the live ones. Reuse the slot already
// holding this command, or re-running setup stacks duplicate shortcuts.
async function bindCinnamonHotkey(name: string, command: string, binding: string): Promise<void> {
  const schemaFor = (slot: string) =>
    `org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/${slot}/`;

  const list = await gsettingsGet(['org.cinnamon.desktop.keybindings', 'custom-list']);
  const slots = [...list.matchAll(/'([^']+)'/g)].map(match => match[1]);

  let slot = '';
  for (const candidate of slots) {
    if (await gsettingsGet([schemaFor(candidate), 'command']) === `'${command}'`) {
      slot = candidate;
      break;
    }
  }

  if (!slot) {
    let index = 0;
    while (slots.includes(`custom${index}`)) index++;
    slot = `custom${index}`;
    slots.push(slot);
  }

  // Fill the slot before advertising it in custom-list. The reverse order
  // leaves a blank shortcut in Cinnamon's keyboard panel if anything fails
  // in between, and no later run can match or reclaim it.
  await execa('gsettings', ['set', schemaFor(slot), 'name', `'${name}'`]);
  await execa('gsettings', ['set', schemaFor(slot), 'command', `'${command}'`]);
  await execa('gsettings', ['set', schemaFor(slot), 'binding', `['${binding}']`]);

  if (!list.includes(`'${slot}'`)) {
    await execa('gsettings', ['set', 'org.cinnamon.desktop.keybindings', 'custom-list',
      `[${slots.map(s => `'${s}'`).join(', ')}]`]);
  }

  log(`Bound ${binding} -> ${command} (${slot})`, 'success');
}

function osField(name: string, text: string): string {
  return text.match(new RegExp(`^${name}="?([^"\\n]+)"?`, 'm'))?.[1] ?? '';
}

// ghostty-ubuntu names Ubuntu assets by version ("24.04") but Debian assets by
// codename ("trixie"), so the two need different fields. Mint reports its own
// version (22.3), with the Ubuntu base in the upstream-release file it ships.
// Returns '' when nothing matches, which callers must treat as unsupported
// rather than splicing an empty string into a filename.
function debReleaseTag(): string {
  const osRelease = readFileSync('/etc/os-release', 'utf8');

  if (osField('ID', osRelease) === 'debian') return osField('VERSION_CODENAME', osRelease);

  const upstream = '/etc/upstream-release/lsb-release';
  if (existsSync(upstream)) return osField('DISTRIB_RELEASE', readFileSync(upstream, 'utf8'));

  return osField('VERSION_ID', osRelease);
}

async function installUlauncher(): Promise<void> {
  if (await commandExists('ulauncher')) {
    log('Ulauncher is already installed', 'success');
    return;
  }

  const spinner = ora('Installing Ulauncher...').start();
  try {
    await execa('bash', ['-c', [
      'sudo -n add-apt-repository -y ppa:agornostal/ulauncher',
      'sudo -n apt-get update -y',
      'sudo -n apt-get install -y ulauncher'
    ].join(' && ')]);
    spinner.succeed('Ulauncher installed');
  } catch (error) {
    spinner.fail('Failed to install Ulauncher');
    log(error instanceof Error ? error.message : 'Unknown error', 'error');
  }
}

// The hotkey is useless without a live daemon, and neither the autostart entry
// nor starting it needs root — so this must stay outside the sudo-gated
// install, or an already-installed machine gets a shortcut pointing at nothing.
async function ensureUlauncherRunning(): Promise<void> {
  if (!await commandExists('ulauncher')) return;

  const autostart = join(HOME, '.config/autostart/ulauncher.desktop');
  if (!existsSync(autostart)) {
    mkdirSync(dirname(autostart), { recursive: true });
    writeFileSync(autostart, [
      '[Desktop Entry]',
      'Type=Application',
      'Name=Ulauncher',
      'Exec=ulauncher --hide-window',
      'Icon=ulauncher',
      'X-GNOME-Autostart-enabled=true',
      ''
    ].join('\n'));
    log(`Created ${autostart}`, 'success');
  }

  try {
    // -x matches the process name exactly. -f would scan whole command lines
    // and match any shell that merely mentions "ulauncher", including this
    // script's own invocation — a false positive that skips the start below.
    await execa('pgrep', ['-x', 'ulauncher']);
    log('Ulauncher daemon already running', 'success');
    return;
  } catch {
    // pgrep exits non-zero when nothing matches — nothing is running yet.
  }

  const launcher = execa('ulauncher', ['--hide-window'], { detached: true, stdio: 'ignore' });
  launcher.unref();
  launcher.catch(() => {});

  // stdio is 'ignore' and the rejection is discarded, so spawning tells us
  // nothing. Confirm it is actually alive — otherwise we bind Alt+Space to a
  // launcher that died on startup and report it as a success.
  await new Promise(resolve => setTimeout(resolve, 2000));
  try {
    await execa('pgrep', ['-x', 'ulauncher']);
    log('Started Ulauncher daemon', 'success');
  } catch {
    log('Ulauncher did not stay running — try "ulauncher --hide-window" by hand to see why', 'warning');
  }
}

// Cinnamon's keyboard panel only accepts key combos, so the mouse side buttons
// (X numbers them 8/9) need xbindkeys holding a grab on them. Nothing here wants
// root, so it stays outside the sudo-gated installs — same reasoning as
// ensureUlauncherRunning.
async function ensureXbindkeys(): Promise<void> {
  if (!await commandExists('xbindkeys')) return;

  // xbindkeys grabs through X. Under Wayland it starts, binds nothing, and
  // reports success — worse than not running at all.
  if (process.env.XDG_SESSION_TYPE === 'wayland') {
    log('Wayland session — xbindkeys cannot grab mouse buttons, skipping', 'warning');
    return;
  }

  await createSymlink(join(DOTFILES_DIR, 'xbindkeys/.xbindkeysrc'), join(HOME, '.xbindkeysrc'));
  await fsExtra.ensureDir(join(HOME, '.local/bin'));
  await createSymlink(join(DOTFILES_DIR, 'xbindkeys/app-expose'), join(HOME, '.local/bin/app-expose'));
  await createSymlink(join(DOTFILES_DIR, 'xbindkeys/mission-control'), join(HOME, '.local/bin/mission-control'));
  await createSymlink(join(DOTFILES_DIR, 'xbindkeys/tile'), join(HOME, '.local/bin/tile'));

  if (!await commandExists('rofi')) {
    log('rofi not installed — mouse button 5 (App Exposé) will do nothing', 'warning');
  }
  if (!await commandExists('wmctrl')) {
    log('wmctrl not installed — the Ctrl+Super tiling keys will do nothing', 'warning');
  }

  const autostart = join(HOME, '.config/autostart/xbindkeys.desktop');
  if (!existsSync(autostart)) {
    mkdirSync(dirname(autostart), { recursive: true });
    writeFileSync(autostart, [
      '[Desktop Entry]',
      'Type=Application',
      'Name=xbindkeys',
      'Exec=xbindkeys',
      'X-GNOME-Autostart-enabled=true',
      'NoDisplay=true',
      ''
    ].join('\n'));
    log(`Created ${autostart}`, 'success');
  }

  // Unconditional restart: xbindkeys reads ~/.xbindkeysrc once at startup, so an
  // instance left over from before this run would keep serving stale bindings.
  // pkill returns once the signal is sent, not once the process is gone — spawn
  // into the old instance's still-live button grabs and the new one comes up
  // bound to nothing, which the pgrep check below would happily call a success.
  await execa('bash', ['-c',
    'pkill -x xbindkeys || true; timeout 5 sh -c "while pgrep -x xbindkeys >/dev/null; do sleep 0.1; done"'
  ]).catch(() => {});

  const daemon = execa('xbindkeys', [], { detached: true, stdio: 'ignore' });
  daemon.unref();
  daemon.catch(() => {});

  // xbindkeys exits on a config it cannot parse, and stdio is discarded above,
  // so spawning it proves nothing on its own.
  await new Promise(resolve => setTimeout(resolve, 1000));
  try {
    await execa('pgrep', ['-x', 'xbindkeys']);
    log('xbindkeys running — mouse buttons 4/5 = Expo/App Exposé, Ctrl+Super+arrows/letters tile', 'success');
  } catch {
    log('xbindkeys did not stay running — run "xbindkeys -n -v" to see why', 'warning');
  }
}

async function aptCandidateExists(pkg: string): Promise<boolean> {
  try {
    const { stdout } = await execa('apt-cache', ['policy', pkg]);
    // An unknown package prints nothing at all; a known-but-unavailable one
    // prints "Candidate: (none)".
    return stdout.includes('Candidate:') && !stdout.includes('Candidate: (none)');
  } catch {
    return false;
  }
}

// Ghostty reached the official Ubuntu archive in 26.04. On older bases (Mint
// 22.x sits on noble/24.04) there is no apt candidate, and upstream ships no
// binaries of its own, so fall back to the community .deb builds. Those assets
// spell the version ".ppaN" where the git tag says "-ppaN" — guess that wrong
// and the download 404s.
async function installGhostty(): Promise<void> {
  if (await commandExists('ghostty')) {
    log('Ghostty is already installed', 'success');
    return;
  }

  if (await aptCandidateExists('ghostty')) {
    await installAptPackage('ghostty');
    return;
  }

  const release = debReleaseTag();
  if (!release) {
    log('Could not determine the distro release, skipping Ghostty', 'warning');
    return;
  }

  const spinner = ora('Installing Ghostty...').start();
  try {
    const { stdout: arch } = await execa('dpkg', ['--print-architecture']);
    const { stdout: json } = await execa('curl', ['-fsSL',
      'https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest']);
    const tag = JSON.parse(json).tag_name as string;

    const deb = `ghostty_${tag.replace(/-(ppa\d+)$/, '.$1')}_${arch}_${release}.deb`;
    const debPath = join('/tmp', deb);
    const url = `https://github.com/mkasberg/ghostty-ubuntu/releases/download/${tag}/${deb}`;

    // No shell here on purpose: `deb` is built from a network-supplied tag, and
    // an unquoted expansion in `bash -c` would word-split or execute on any
    // metacharacter that turns up in it.
    await execa('curl', ['-fLo', debPath, url]);
    await execa('sudo', ['-n', 'apt-get', 'install', '-y', debPath]);
    await fsExtra.remove(debPath);
    spinner.succeed(`Ghostty ${tag} installed`);
  } catch (error) {
    spinner.fail(`Failed to install Ghostty (no build for ${release}?)`);
    log(error instanceof Error ? error.message : 'Unknown error', 'error');
  }
}

// Seam for plain-apt desktop apps — adding the next one is a single call.
async function installAptPackage(pkg: string): Promise<void> {
  if (await commandExists(pkg)) {
    log(`${pkg} is already installed`, 'success');
    return;
  }

  const spinner = ora(`Installing ${pkg}...`).start();
  try {
    await execa('sudo', ['-n', 'apt-get', 'install', '-y', pkg]);
    spinner.succeed(`${pkg} installed`);
  } catch (error) {
    spinner.fail(`Failed to install ${pkg}`);
    log(error instanceof Error ? error.message : 'Unknown error', 'error');
  }
}

async function configureCinnamon(): Promise<void> {
  // expo = Mission Control, scale = App Exposé. Only touched while every corner
  // is still off, so a later hand-tuned layout survives a re-run.
  const corners = await gsettingsGet(['org.cinnamon', 'hotcorner-layout']);
  if (corners.includes(':true:')) {
    log('Hot corners already configured, leaving as-is', 'success');
  } else {
    await execa('gsettings', ['set', 'org.cinnamon', 'hotcorner-layout',
      "['expo:true:0', 'scale:true:0', 'scale:false:0', 'desktop:false:0']"]);
    log('Hot corners: top-left Expo, top-right App Exposé', 'success');
  }

  if (await commandExists('ulauncher')) {
    // Cinnamon ships Alt+Space bound to the window menu; the launcher never
    // sees the key until that one is cleared.
    const windowMenu = await gsettingsGet(['org.cinnamon.desktop.keybindings.wm', 'activate-window-menu']);
    if (windowMenu.includes('<Alt>space')) {
      await execa('gsettings', ['set', 'org.cinnamon.desktop.keybindings.wm', 'activate-window-menu', '[]']);
      log('Freed Alt+Space from the window-menu shortcut', 'info');
    }
    await bindCinnamonHotkey('Ulauncher', 'ulauncher-toggle', '<Alt>space');
  }

  // Super sits where Cmd does, so this becomes Cmd+Shift+4 the moment a
  // Mac-style remapper is in play, and is harmless before that. Cinnamon's own
  // screenshot shortcuts all live on Print, so nothing collides.
  if (await commandExists('flameshot')) {
    await bindCinnamonHotkey('Flameshot', 'flameshot gui', '<Shift><Super>4');
  }
}

async function setupLinuxDesktop(): Promise<void> {
  if (IS_CI) return;
  if (!HAS_DESKTOP) {
    log('No graphical session detected (XDG_CURRENT_DESKTOP unset), skipping desktop setup', 'warning');
    return;
  }

  if (!await promptUser('Set up desktop apps? (Ulauncher, Ghostty, Flameshot, mouse buttons + Cinnamon settings)', false)) {
    log('Skipped desktop setup', 'warning');
    return;
  }

  // Cinnamon runs on non-Debian distros too, where these installers are simply
  // absent — one clean skip beats three ENOENT stack traces.
  if (!await commandExists('apt-get')) {
    log('apt-get not found — skipping app installs, applying desktop settings only', 'warning');
  } else if (await ensureSudo()) {
    await installUlauncher();
    await installGhostty();
    await installAptPackage('flameshot');
    await installAptPackage('xbindkeys');
    // Cinnamon has no per-app window overview, so App Exposé is rofi's window
    // mode filtered to one WM_CLASS — see xbindkeys/app-expose.
    await installAptPackage('rofi');
    // xbindkeys/tile moves the active window through wmctrl's EWMH messages.
    await installAptPackage('wmctrl');
  } else {
    // Settings below need no root, so a failed sudo must not skip them too.
    log('No sudo access — skipping app installs, applying desktop settings only', 'warning');
  }

  await ensureUlauncherRunning();

  const desktop = process.env.XDG_CURRENT_DESKTOP ?? '';
  if (!desktop.toLowerCase().includes('cinnamon')) {
    log(`${desktop || 'This desktop'} is not Cinnamon — set the shortcuts and mouse bindings manually`, 'warning');
    return;
  }

  await configureCinnamon();
  await ensureXbindkeys();
}

async function installPackages(): Promise<void> {
  if (options.skipPackages) {
    log('Skipping package installation (--skip-packages flag)', 'warning');
    return;
  }

  if (IS_MACOS) {
    await installBrewPackages();
  } else if (IS_LINUX) {
    // apt first: Homebrew's installer needs build-essential, curl and git.
    // Then brew for current versions, which leaves the per-tool installers
    // below as no-ops for anything it already provided.
    await installAptPackages();
    await installHomebrewLinux();
    await installBrewPackages();
    await createLinuxCompatSymlinks();
    await installSpecialPackagesLinux();
    await setDefaultShellZsh();
    // Desktop tweaks are cosmetic and gsettings has plenty of ways to fail —
    // missing schema, no D-Bus session, dconf unable to commit. Letting one
    // throw here would reach main()'s catch and skip symlinks, secrets and
    // fonts, i.e. everything the setup actually exists for. Under --desktop
    // this guard is absent by design, so an explicit request still fails loud.
    await setupLinuxDesktop().catch(error => {
      log(`Desktop setup failed: ${error instanceof Error ? error.message : 'Unknown error'}`, 'error');
    });
  } else {
    log('Unsupported platform. Skipping package installation.', 'warning');
  }
}

// Copied rather than symlinked: macOS CoreText is unreliable about symlinked
// faces in ~/Library/Fonts, and fonts change far too rarely to be worth the
// inconsistency of doing it two different ways per platform.
async function installFonts(): Promise<void> {
  const fontsDir = join(DOTFILES_DIR, 'fonts');
  if (!existsSync(fontsDir)) {
    log('No fonts directory in repo, skipping font installation', 'warning');
    return;
  }

  const target = IS_MACOS ? join(HOME, 'Library/Fonts') : join(HOME, '.local/share/fonts');
  // Families live in subdirectories next to licences and READMEs, so recurse
  // and keep only the actual faces.
  const faces = readdirSync(fontsDir, { recursive: true, encoding: 'utf8' })
    .filter(file => /\.(ttf|otf|ttc)$/i.test(file));

  if (faces.length === 0) {
    log('No font files found in fonts/, skipping', 'warning');
    return;
  }

  mkdirSync(target, { recursive: true });

  let installed = 0;
  for (const face of faces) {
    const dest = join(target, basename(face));
    if (existsSync(dest)) continue;
    copyFileSync(join(fontsDir, face), dest);
    installed++;
  }

  if (installed === 0) {
    log(`Fonts already installed in ${target} (${faces.length} faces)`, 'success');
  } else {
    log(`Installed ${installed} font face(s) to ${target}`, 'success');
  }

  // macOS picks up ~/Library/Fonts on its own; fontconfig needs telling.
  if (IS_LINUX && !IS_CI && installed > 0 && await commandExists('fc-cache')) {
    const spinner = ora('Refreshing font cache...').start();
    try {
      await execa('fc-cache', ['-f', target]);
      spinner.succeed('Font cache refreshed');
    } catch {
      spinner.warn('Could not refresh font cache — run "fc-cache -f" manually');
    }
  }
}

async function installTPM(): Promise<void> {
  const tpmPath = join(HOME, '.tmux/plugins/tpm');

  if (existsSync(tpmPath)) {
    log('TPM is already installed', 'success');
    return;
  }

  const spinner = ora('Installing Tmux Plugin Manager (TPM)...').start();

  try {
    await fsExtra.ensureDir(dirname(tpmPath));
    await execa('git', ['clone', 'https://github.com/tmux-plugins/tpm', tpmPath]);
    spinner.succeed('TPM installed successfully');
  } catch (error) {
    spinner.fail('Failed to install TPM');
    log(error instanceof Error ? error.message : 'Unknown error', 'error');
  }
}

async function installTmuxPlugins(): Promise<void> {
  if (IS_CI) {
    log('Detected CI environment. Skipping plugin installation.', 'warning');
    log('In production, run tmux and press prefix + I to install plugins.', 'info');
    return;
  }

  const tpmInstaller = join(HOME, '.tmux/plugins/tpm/bin/install_plugins');
  if (!existsSync(tpmInstaller)) {
    log('TPM not installed or not found, skipping plugin installation', 'warning');
    return;
  }

  if (!await commandExists('tmux')) {
    log('tmux command not found, skipping plugin installation', 'warning');
    return;
  }

  const spinner = ora('Installing tmux plugins...').start();

  try {
    await execa(tpmInstaller, [], { stdio: 'ignore' });
    spinner.succeed('Tmux plugins installed');
  } catch {
    spinner.warn('Run tmux and press prefix + I to install plugins manually');
  }
}

async function setupLazyVim(): Promise<void> {
  const nvimConfigPath = join(HOME, '.config/nvim');
  const dotfilesNvimPath = join(DOTFILES_DIR, '.config/nvim');
  
  // Check if we're setting up fresh or updating existing
  if (existsSync(nvimConfigPath)) {
    // Check if it's already a symlink to our dotfiles
    try {
      const stats = lstatSync(nvimConfigPath);
      if (stats.isSymbolicLink() && readlinkSync(nvimConfigPath) === dotfilesNvimPath) {
        log('Neovim config already linked to dotfiles', 'success');
        return;
      }
    } catch {
      // Not a symlink, continue
    }
    
    // Handle existing config
    log(`Existing Neovim config found at ${nvimConfigPath}`, 'warning');
    
    let shouldReplace = options.forceOverwrite;
    if (!options.nonInteractive && !options.forceOverwrite) {
      shouldReplace = await promptUser(`Replace existing Neovim config? (backup will be created)`, true);
    }
    
    if (shouldReplace) {
      const backupPath = `${nvimConfigPath}.bak.${Date.now()}`;
      log(`Backing up existing Neovim config to ${backupPath}`, 'info');
      await fsExtra.move(nvimConfigPath, backupPath);
    } else {
      log('Skipped Neovim config setup', 'warning');
      return;
    }
  }
  
  // Check if LazyVim starter needs to be cloned into dotfiles
  if (!existsSync(join(dotfilesNvimPath, 'init.lua'))) {
    const spinner = ora('Cloning LazyVim starter...').start();
    try {
      // Clone LazyVim starter to temp location
      const tempDir = join(HOME, '.config', 'nvim-temp-' + Date.now());
      await execa('git', ['clone', 'https://github.com/LazyVim/starter', tempDir]);
      
      // Remove .git directory
      await fsExtra.remove(join(tempDir, '.git'));
      
      // Copy to dotfiles
      await fsExtra.copy(tempDir, dotfilesNvimPath);
      
      // Clean up temp directory
      await fsExtra.remove(tempDir);
      
      spinner.succeed('LazyVim starter cloned to dotfiles');
    } catch (error) {
      spinner.fail('Failed to clone LazyVim starter');
      throw error;
    }
  }
  
  // Create symlink
  symlinkSync(dotfilesNvimPath, nvimConfigPath);
  log(`Created symlink: ${nvimConfigPath} -> ${dotfilesNvimPath}`, 'success');
}

async function setupSecretsFile(): Promise<void> {
  const secretsPath = join(HOME, '.secrets');
  const zshrcCorePath = join(DOTFILES_DIR, 'zsh/.zshrc.core');
  const zshrcPath = join(DOTFILES_DIR, 'zsh/.zshrc'); // fallback for backward compatibility

  if (existsSync(secretsPath)) {
    log('~/.secrets already exists, preserving existing file', 'success');
    return;
  }

  log('Creating ~/.secrets file...', 'info');

  const secrets: Record<string, string> = {};

  // Check .zshrc.core first, then fallback to .zshrc for backward compatibility
  const configPath = existsSync(zshrcCorePath) ? zshrcCorePath : zshrcPath;

  if (existsSync(configPath)) {
    const zshrcContent = readFileSync(configPath, 'utf8');

    const tokenMatch = zshrcContent.match(/export BITBUCKET_TOKEN="?([^"\n]+)"?/);
    if (tokenMatch && tokenMatch[1] && tokenMatch[1] !== '') {
      secrets.BITBUCKET_TOKEN = tokenMatch[1];
    }

    const usernameMatch = zshrcContent.match(/export BITBUCKET_USERNAME="?([^"\n]+)"?/);
    if (usernameMatch && usernameMatch[1]) {
      secrets.BITBUCKET_USERNAME = usernameMatch[1];
    }

    const openaiMatch = zshrcContent.match(/export OPENAI_API_KEY="?([^"\n]+)"?/);
    if (openaiMatch && openaiMatch[1] && openaiMatch[1] !== '') {
      secrets.OPENAI_API_KEY = openaiMatch[1];
    }
  }

  let secretsContent = '#!/bin/bash\n';
  secretsContent += '# This file contains sensitive credentials and is not tracked by git\n';
  secretsContent += '# Generated by dotfiles setup script\n\n';

  if (secrets.BITBUCKET_USERNAME) {
    secretsContent += `export BITBUCKET_USERNAME="${secrets.BITBUCKET_USERNAME}"\n`;
  } else {
    secretsContent += 'export BITBUCKET_USERNAME="your.username"\n';
  }

  if (secrets.BITBUCKET_TOKEN) {
    secretsContent += `export BITBUCKET_TOKEN="${secrets.BITBUCKET_TOKEN}"\n`;
  } else {
    secretsContent += 'export BITBUCKET_TOKEN="your-token-here"\n';
  }

  if (secrets.OPENAI_API_KEY) {
    secretsContent += `export OPENAI_API_KEY="${secrets.OPENAI_API_KEY}"\n`;
  } else {
    secretsContent += 'export OPENAI_API_KEY="your-api-key-here"\n';
  }

  // Used by the codex brave-search MCP wrapper (see codex/config.example.toml)
  secretsContent += 'export BRAVE_API_KEY="your-api-key-here"\n';

  secretsContent += '\n# Add other secrets below as needed\n';

  writeFileSync(secretsPath, secretsContent, { mode: 0o600 });
  log(`Created ~/.secrets with proper permissions (600)`, 'success');

  if (Object.keys(secrets).length > 0) {
    const sourceFile = configPath.includes('.zshrc.core') ? '.zshrc.core' : '.zshrc';
    log(`Migrated ${Object.keys(secrets).length} secret(s) from ${sourceFile} to ~/.secrets`, 'info');
  }
}

// Config files mapping — explicit allowlist; never glob ~/.claude or ~/.codex
// (those dirs are dominated by machine state, caches, and credentials)
const SYMLINKS: [string, string][] = [
  // .config directory items
  [join(DOTFILES_DIR, '.config/ghostty'), join(HOME, '.config/ghostty')],
  [join(DOTFILES_DIR, '.config/starship.toml'), join(HOME, '.config/starship.toml')],
  [join(DOTFILES_DIR, '.config/atuin'), join(HOME, '.config/atuin')],
  [join(DOTFILES_DIR, '.config/sheldon'), join(HOME, '.config/sheldon')],
  [join(DOTFILES_DIR, '.config/yazi'), join(HOME, '.config/yazi')],
  // Home directory dotfiles
  [join(DOTFILES_DIR, 'zsh/.zprofile'), join(HOME, '.zprofile')],
  [join(DOTFILES_DIR, 'zsh/.zshrc'), join(HOME, '.zshrc')],
  [join(DOTFILES_DIR, 'zsh/.zshrc.core'), join(HOME, '.zshrc.core')],
  [join(DOTFILES_DIR, 'tmux/.tmux.conf'), join(HOME, '.tmux.conf')],
  // Claude Code custom config
  [join(DOTFILES_DIR, 'claude/CLAUDE.md'), join(HOME, '.claude/CLAUDE.md')],
  [join(DOTFILES_DIR, 'claude/AGENTS.md'), join(HOME, '.claude/AGENTS.md')],
  [join(DOTFILES_DIR, 'claude/settings.json'), join(HOME, '.claude/settings.json')],
  [join(DOTFILES_DIR, 'claude/commands'), join(HOME, '.claude/commands')],
  [join(DOTFILES_DIR, 'claude/skills'), join(HOME, '.claude/skills')],
  // Codex custom config (config.toml is copy-if-absent, see setupCodexConfig —
  // codex appends project trust entries at runtime, so it must not live in git)
  [join(DOTFILES_DIR, 'codex/keybindings.json'), join(HOME, '.codex/keybindings.json')],
  [join(DOTFILES_DIR, 'codex/AGENTS.md'), join(HOME, '.codex/AGENTS.md')],
  [join(DOTFILES_DIR, 'codex/instructions.md'), join(HOME, '.codex/instructions.md')],
  [join(DOTFILES_DIR, 'codex/rules'), join(HOME, '.codex/rules')]
];

async function setupCodexConfig(): Promise<void> {
  const source = join(DOTFILES_DIR, 'codex/config.example.toml');
  const target = join(HOME, '.codex/config.toml');

  if (!existsSync(source)) {
    log(`Source file not found: ${source} - skipping`, 'warning');
    return;
  }

  if (existsSync(target)) {
    log('Codex config.toml already exists, preserving (template is copy-if-absent)', 'success');
    return;
  }

  await fsExtra.copy(source, target);
  log(`Created ${target} from config.example.toml (remember to set BRAVE_API_KEY in ~/.secrets)`, 'success');
}

async function createSymlinks(): Promise<void> {
  log('Creating symlinks...', 'info');

  await fsExtra.ensureDir(join(HOME, '.config'));
  await fsExtra.ensureDir(join(HOME, '.claude'));
  await fsExtra.ensureDir(join(HOME, '.codex'));

  // Handle nvim separately with LazyVim setup
  await setupLazyVim();

  for (const [source, target] of SYMLINKS) {
    await createSymlink(source, target);
  }

  await setupCodexConfig();
}

async function sourceZshrc(): Promise<void> {
  if (IS_CI) {
    log('Skipping .zshrc sourcing in CI environment', 'warning');
    return;
  }

  if (!await commandExists('zsh')) {
    log('zsh shell not found. Please run "source ~/.zshrc" manually', 'warning');
    return;
  }

  const spinner = ora('Attempting to source .zshrc...').start();

  try {
    await execa('zsh', ['-c', 'source ~/.zshrc']);
    spinner.succeed('zshrc sourced successfully!');
  } catch {
    spinner.warn('Couldn\'t automatically source .zshrc');
  }
}

function verifySetup(): void {
  log('Verifying managed files...', 'info');
  let failures = 0;

  const links: [string, string][] = [
    ...SYMLINKS,
    [join(DOTFILES_DIR, '.config/nvim'), join(HOME, '.config/nvim')]
  ];

  for (const [source, target] of links) {
    if (!existsSync(source)) {
      log(`SKIP (no source in repo): ${target}`, 'warning');
      continue;
    }
    try {
      const stats = lstatSync(target);
      if (!stats.isSymbolicLink()) {
        // A tool doing atomic temp+rename writes can silently replace a symlink
        // with a regular file — this is exactly what this check exists to catch.
        log(`NOT A SYMLINK (sync broken, file drifted?): ${target}`, 'error');
        failures++;
      } else if (readlinkSync(target) !== source) {
        log(`WRONG TARGET: ${target} -> ${readlinkSync(target)} (expected ${source})`, 'error');
        failures++;
      } else {
        log(`ok: ${target}`, 'success');
      }
    } catch {
      log(`MISSING: ${target}`, 'error');
      failures++;
    }
  }

  const secretsPath = join(HOME, '.secrets');
  if (existsSync(secretsPath)) {
    const mode = lstatSync(secretsPath).mode & 0o777;
    if (mode !== 0o600) {
      log(`~/.secrets has mode ${mode.toString(8)}, expected 600`, 'error');
      failures++;
    } else {
      log('ok: ~/.secrets permissions (600)', 'success');
    }
  } else {
    log('~/.secrets not found', 'warning');
  }

  if (failures > 0) {
    log(`Verification failed: ${failures} issue(s)`, 'error');
    process.exit(1);
  }
  log('All managed files verified', 'success');
}

// Main setup function
async function main(): Promise<void> {
  if (options.verify) {
    verifySetup();
    return;
  }
  console.log(chalk.green.bold('Setting up dotfiles...'));
  console.log(chalk.blue(`Working directory: ${DOTFILES_DIR}`));

  try {
    if (options.desktop) {
      // Explicitly requested work: refuse loudly rather than exit 0 having done
      // nothing, which is indistinguishable from success.
      if (!IS_LINUX) {
        log('--desktop is Linux-only', 'error');
        process.exit(1);
      }
      if (!HAS_DESKTOP) {
        log('No graphical session detected (XDG_CURRENT_DESKTOP unset).', 'error');
        log('Run this from a desktop session — not SSH, a plain VT, or a pre-login tmux server.', 'error');
        process.exit(1);
      }
      await setupLinuxDesktop();
      return;
    }

    // Install required packages
    await installPackages();

    // Install bundled fonts (both platforms)
    await installFonts();

    // Install tmux plugin manager
    await installTPM();

    // Setup secrets file before creating symlinks
    await setupSecretsFile();

    // Create symlinks
    await createSymlinks();

    // Source zsh configuration
    await sourceZshrc();

    // Install tmux plugins
    await installTmuxPlugins();

    console.log(chalk.green.bold('\nSetup completed successfully!'));
    console.log(chalk.green('All dotfiles are linked and tools are installed!'));

    if (IS_CI) {
      console.log(chalk.blue('CI setup complete. Symlinks created and packages installed.'));
    } else {
      console.log(chalk.yellow('\nNOTE: If you\'d like to try your new settings, you can run "exec zsh -l" to start a new login shell'));
    }
  } catch (error) {
    console.error(chalk.red('Setup failed:'), error);
    process.exit(1);
  } finally {
    stopSudoKeepAlive();
  }
}

// Run the setup
main();
