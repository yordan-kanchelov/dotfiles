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

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const DOTFILES_DIR = __dirname;
const HOME = homedir();
const BACKUP_DIR = join(HOME, '.dotfiles_backup', new Date().toISOString().replace(/:/g, '-'));
const IS_CI = Boolean(process.env.CI || process.env.GITHUB_ACTIONS);
const IS_MACOS = platform() === 'darwin';

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

  const backupPath = join(BACKUP_DIR, filePath.replace(/^\//, '').replace(/\//g, '_') + '.bak');
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

  // Special handling for shell config files
  const configFiles = ['.zshrc', '.bashrc', '.bash_profile'];
  if (configFiles.some(file => targetFile.endsWith(file))) {
    await handleConfigFile(sourceFile, targetFile);
  } else {
    // Standard symlink behavior
    let targetExists = false;
    try {
      targetExists = existsSync(targetFile) || lstatSync(targetFile).isSymbolicLink();
    } catch {
      // Ignore error - broken symlink
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

async function installHomebrew(): Promise<string> {
  const spinner = ora('Installing Homebrew...').start();

  try {
    const installScript = await execa('curl', ['-fsSL', 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh']);
    const env = IS_CI ? { NONINTERACTIVE: '1' } : {};
    await execa('bash', ['-c', installScript.stdout], { env, stdio: 'inherit' });

    // Set up Homebrew in PATH
    const brewPath = existsSync('/opt/homebrew/bin/brew') ? '/opt/homebrew/bin/brew' : '/usr/local/bin/brew';
    const { stdout } = await execa(brewPath, ['shellenv']);

    // Add to shell profile
    const profilePath = join(HOME, '.zprofile');
    const profileContent = existsSync(profilePath) ? readFileSync(profilePath, 'utf8') : '';
    if (!profileContent.includes('brew shellenv')) {
      await fsExtra.appendFile(profilePath, `\neval "$(${brewPath} shellenv)"\n`);
    }

    spinner.succeed('Homebrew installed successfully');
    return brewPath;
  } catch (error) {
    spinner.fail('Failed to install Homebrew');
    throw error;
  }
}

async function installPackages(): Promise<void> {
  if (options.skipPackages) {
    log('Skipping package installation (--skip-packages flag)', 'warning');
    return;
  }

  if (!IS_MACOS) {
    log('Warning: This script is optimized for macOS. Skipping package installation.', 'warning');
    return;
  }

  log('Installing required packages with Homebrew...', 'info');

  // Check if Homebrew is installed
  let brewPath = await commandExists('brew') ? 'brew' : null;
  if (!brewPath) {
    brewPath = await installHomebrew();
  }

  // Install packages from brew_packages.txt
  const packagesFile = join(DOTFILES_DIR, 'brew_packages.txt');
  if (!existsSync(packagesFile)) {
    log('Error: brew_packages.txt not found', 'error');
    return;
  }

  const packages = readFileSync(packagesFile, 'utf8')
    .split('\n')
    .filter(line => line.trim() && !line.trim().startsWith('#'));

  const failedPackages: string[] = [];

  for (const pkg of packages) {
    const spinner = ora(`Installing ${pkg}...`).start();
    try {
      await execa(brewPath, ['install', pkg], {
        timeout: IS_CI ? 300000 : undefined // 5 minute timeout in CI
      });
      spinner.succeed(`Successfully installed ${pkg}`);
    } catch (error) {
      spinner.fail(`Failed to install ${pkg}`);
      failedPackages.push(pkg);
    }
  }

  if (failedPackages.length > 0) {
    log(`Failed to install packages: ${failedPackages.join(', ')}`, 'warning');
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
  } catch (error: any) {
    spinner.fail('Failed to install TPM');
    log(error.message || 'Unknown error', 'error');
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
    // Home directory dotfiles
    [join(DOTFILES_DIR, 'zsh/.zshrc'), join(HOME, '.zshrc')],
    [join(DOTFILES_DIR, 'tmux/.tmux.conf'), join(HOME, '.tmux.conf')]
  ];

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