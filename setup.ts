#!/usr/bin/env node --experimental-strip-types
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync, symlinkSync, readlinkSync, lstatSync, readdirSync } from 'fs';
import { homedir, platform } from 'os';
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

// Type definitions
interface SetupOptions {
  nonInteractive?: boolean;
  forceOverwrite?: boolean;
  append?: boolean;
  skipPackages?: boolean;
  interactive?: boolean;
}

type LogType = 'info' | 'success' | 'warning' | 'error';

// Parse command line options
program
  .option('--non-interactive', 'Run without prompts')
  .option('--force-overwrite', 'Overwrite existing files without prompting')
  .option('--append', 'Append to existing config files instead of symlinking')
  .option('--skip-packages', 'Skip package installation')
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
  return Object.values(data ?? {})
    .filter(val => Array.isArray(val))
    .flat() as string[];
}

async function installBrewPackages(): Promise<void> {
  if (!await commandExists('brew')) {
    log('Error: Homebrew not found. Please run bootstrap.sh first.', 'error');
    process.exit(1);
  }

  log('Installing required packages with Homebrew...', 'info');

  const { formulae, casks } = parseBrewPackages(join(DOTFILES_DIR, 'brew_packages.yml'));
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

async function installAptPackages(): Promise<void> {
  if (!await commandExists('apt-get')) {
    log('Error: apt-get not found. Skipping APT package installation.', 'error');
    return;
  }

  log('Installing required packages with APT...', 'info');

  const spinner = ora('Updating package lists...').start();
  try {
    await execa('sudo', ['apt-get', 'update', '-y'], {
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
      await execa('sudo', ['apt-get', 'install', '-y', ...batch], {
        timeout: IS_CI ? 300000 : undefined
      });
      batchSpinner.succeed(`Installed: ${batch.join(', ')}`);
    } catch {
      batchSpinner.warn(`Batch failed, trying individually: ${batch.join(', ')}`);
      for (const pkg of batch) {
        const pkgSpinner = ora(`Installing ${pkg}...`).start();
        try {
          await execa('sudo', ['apt-get', 'install', '-y', pkg], {
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

async function installSpecialPackagesLinux(): Promise<void> {
  log('Installing tools that require special installation methods...', 'info');

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
      await execa('bash', ['-c', 'curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh']);
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
      await execa('bash', ['-c', `curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_${arch}.tar.gz" && tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && sudo install /tmp/lazygit /usr/local/bin && rm /tmp/lazygit.tar.gz /tmp/lazygit`]);
      spinner.succeed('lazygit installed');
    } catch (error) {
      spinner.fail('Failed to install lazygit');
      log(error instanceof Error ? error.message : 'Unknown error', 'error');
    }
  } else {
    log('lazygit is already installed', 'success');
  }

  // gh (GitHub CLI)
  if (!await commandExists('gh')) {
    if (!await commandExists('apt-get')) {
      log('apt-get not found, skipping GitHub CLI installation', 'warning');
    } else {
      const spinner = ora('Installing GitHub CLI...').start();
      try {
        await execa('bash', ['-c', [
          'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg',
          'sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg',
          'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null',
          'sudo apt-get update -y',
          'sudo apt-get install -y gh'
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
}

async function installPackages(): Promise<void> {
  if (options.skipPackages) {
    log('Skipping package installation (--skip-packages flag)', 'warning');
    return;
  }

  if (IS_MACOS) {
    await installBrewPackages();
  } else if (IS_LINUX) {
    await installAptPackages();
    await createLinuxCompatSymlinks();
    await installSpecialPackagesLinux();
  } else {
    log('Unsupported platform. Skipping package installation.', 'warning');
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

  secretsContent += '\n# Add other secrets below as needed\n';

  writeFileSync(secretsPath, secretsContent, { mode: 0o600 });
  log(`Created ~/.secrets with proper permissions (600)`, 'success');

  if (Object.keys(secrets).length > 0) {
    const sourceFile = configPath.includes('.zshrc.core') ? '.zshrc.core' : '.zshrc';
    log(`Migrated ${Object.keys(secrets).length} secret(s) from ${sourceFile} to ~/.secrets`, 'info');
  }
}

async function createSymlinks(): Promise<void> {
  log('Creating symlinks...', 'info');

  // Create config directory
  await fsExtra.ensureDir(join(HOME, '.config'));

  // Config files mapping
  const symlinks: [string, string][] = [
    // .config directory items
    [join(DOTFILES_DIR, '.config/ghostty'), join(HOME, '.config/ghostty')],
    [join(DOTFILES_DIR, '.config/starship.toml'), join(HOME, '.config/starship.toml')],
    [join(DOTFILES_DIR, '.config/atuin'), join(HOME, '.config/atuin')],
    [join(DOTFILES_DIR, '.config/sheldon'), join(HOME, '.config/sheldon')],
    // Home directory dotfiles
    [join(DOTFILES_DIR, 'zsh/.zprofile'), join(HOME, '.zprofile')],
    [join(DOTFILES_DIR, 'zsh/.zshrc'), join(HOME, '.zshrc')],
    [join(DOTFILES_DIR, 'zsh/.zshrc.core'), join(HOME, '.zshrc.core')],
    [join(DOTFILES_DIR, 'tmux/.tmux.conf'), join(HOME, '.tmux.conf')]
  ];
  
  // Handle nvim separately with LazyVim setup
  await setupLazyVim();

  for (const [source, target] of symlinks) {
    await createSymlink(source, target);
  }
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

// Main setup function
async function main(): Promise<void> {
  console.log(chalk.green.bold('Setting up dotfiles...'));
  console.log(chalk.blue(`Working directory: ${DOTFILES_DIR}`));

  try {
    // Install required packages
    await installPackages();

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
      console.log(chalk.yellow('\nNOTE: If you\'d like to try your new settings, you can run "zsh" to start a new shell'));
    }
  } catch (error) {
    console.error(chalk.red('Setup failed:'), error);
    process.exit(1);
  }
}

// Run the setup
main();