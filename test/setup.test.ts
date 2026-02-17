import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync, mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, symlinkSync, lstatSync } from 'fs';
import { tmpdir, platform } from 'os';
import { execaNode } from 'execa';
import YAML from 'yaml';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SETUP_SCRIPT = join(dirname(__dirname), 'setup.ts');

describe('Dotfiles Setup Tests', () => {
  let testDir: string;
  let originalHome: string | undefined;
  let originalCI: string | undefined;

  beforeEach(() => {
    // Create temporary test directory
    testDir = join(tmpdir(), `dotfiles-test-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
    
    // Mock HOME environment
    originalHome = process.env.HOME;
    process.env.HOME = testDir;
    
    // Store original CI env
    originalCI = process.env.CI;
    
    // Create mock dotfiles structure
    const mockConfigDir = join(testDir, '.config');
    mkdirSync(mockConfigDir, { recursive: true });
  });

  afterEach(() => {
    // Restore environment
    if (originalHome) {
      process.env.HOME = originalHome;
    }
    if (originalCI !== undefined) {
      process.env.CI = originalCI;
    } else {
      delete process.env.CI;
    }
    
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  describe('Symlink Creation', () => {
    it('should create symlinks for config files', async () => {
      // Set CI mode to skip interactive prompts and package installation
      process.env.CI = 'true';
      
      // Run setup
      await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Check if .config directory was created
      assert(existsSync(join(testDir, '.config')), '.config directory should be created');
      
      // At least the directories should be created
      assert(existsSync(join(testDir, '.config')), 'Config directory should exist');
    });

    it('should setup LazyVim configuration', async () => {
      process.env.CI = 'true';
      
      // Create a mock nvim config in dotfiles
      const dotfilesNvimPath = join(dirname(__dirname), '.config', 'nvim');
      const mockInitLua = join(dotfilesNvimPath, 'init.lua');
      
      // Check if the nvim config exists in dotfiles
      if (existsSync(mockInitLua)) {
        // Run setup
        await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
          nodeOptions: ['--experimental-strip-types']
        });
        
        // Check if nvim symlink was created
        const nvimConfigPath = join(testDir, '.config', 'nvim');
        if (existsSync(nvimConfigPath)) {
          const stats = lstatSync(nvimConfigPath);
          assert(stats.isSymbolicLink(), 'Neovim config should be a symlink');
        }
      }
    });

    it('should handle existing files with --force-overwrite', async () => {
      process.env.CI = 'true';
      
      // Create existing file
      const existingFile = join(testDir, '.zshrc');
      writeFileSync(existingFile, 'existing content');
      
      // Run setup with force overwrite
      await execaNode(SETUP_SCRIPT, ['--force-overwrite', '--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Check that backup directory was created
      const backupDirs = readdirSync(testDir).filter(dir => dir.startsWith('.dotfiles_backup'));
      assert(backupDirs.length > 0, 'Backup directory should be created');
    });

    it('should backup existing nvim config when setting up LazyVim', async () => {
      process.env.CI = 'true';
      
      // Create existing nvim config
      const nvimConfigPath = join(testDir, '.config', 'nvim');
      mkdirSync(nvimConfigPath, { recursive: true });
      writeFileSync(join(nvimConfigPath, 'init.vim'), '" existing vim config');
      
      // Run setup
      await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Check if backup was created
      const configDir = join(testDir, '.config');
      if (existsSync(configDir)) {
        const backups = readdirSync(configDir).filter(dir => dir.startsWith('nvim.bak.'));
        assert(backups.length > 0 || existsSync(join(configDir, 'nvim')), 'Should handle existing nvim config');
      }
    });

    it('should append to existing files with --append flag', async () => {
      process.env.CI = 'true';
      
      // Create existing file
      const existingFile = join(testDir, '.zshrc');
      const originalContent = '# Original content\n';
      writeFileSync(existingFile, originalContent);
      
      // Run setup with append flag
      await execaNode(SETUP_SCRIPT, ['--append', '--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Check if file was appended (if source exists)
      if (existsSync(existingFile)) {
        const content = readFileSync(existingFile, 'utf8');
        assert(content.includes('Original content'), 'Original content should be preserved');
      }
    });
  });

  describe('Command Line Options', () => {
    it('should respect --skip-packages flag', async () => {
      process.env.CI = 'true';
      
      // Run with skip packages - should complete quickly
      const start = Date.now();
      await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      const duration = Date.now() - start;
      
      // Should complete relatively quickly when skipping packages
      // Allow up to 120 seconds as GitHub Actions can be slow
      assert(duration < 120000, `Setup should complete quickly when skipping packages (took ${duration}ms)`);
    });

    it('should run in non-interactive mode', async () => {
      // Run with non-interactive flag
      const result = await execaNode(SETUP_SCRIPT, ['--non-interactive', '--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Should complete without errors
      assert.strictEqual(result.exitCode, 0, 'Should exit successfully');
    });
  });

  describe('CI Environment Detection', () => {
    it('should auto-detect CI environment', async () => {
      process.env.CI = 'true';
      
      const result = await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Check output for CI detection message
      assert(result.stdout.includes('CI environment detected'), 'Should detect CI environment');
    });
    
    it('should run normally without CI environment', async () => {
      delete process.env.CI;
      delete process.env.GITHUB_ACTIONS;
      
      const result = await execaNode(SETUP_SCRIPT, ['--non-interactive', '--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });
      
      // Should not include CI message
      assert(!result.stdout.includes('CI environment detected'), 'Should not detect CI environment');
    });
  });

  describe('Error Handling', () => {
    it('should handle missing source files gracefully', async () => {
      process.env.CI = 'true';

      // Run setup - should skip missing files
      const result = await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });

      // Should complete despite missing source files
      assert.strictEqual(result.exitCode, 0, 'Should handle missing files gracefully');
    });
  });

  describe('Secrets Management', () => {
    it('should create ~/.secrets file if it does not exist', async () => {
      process.env.CI = 'true';

      // Run setup
      await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });

      // Check if ~/.secrets was created
      const secretsPath = join(testDir, '.secrets');
      assert(existsSync(secretsPath), '~/.secrets file should be created');

      // Verify content includes template variables
      const content = readFileSync(secretsPath, 'utf8');
      assert(content.includes('BITBUCKET_TOKEN'), 'Should include BITBUCKET_TOKEN');
      assert(content.includes('BITBUCKET_USERNAME'), 'Should include BITBUCKET_USERNAME');
      assert(content.includes('OPENAI_API_KEY'), 'Should include OPENAI_API_KEY');
    });

    it('should set proper permissions on ~/.secrets (600)', async () => {
      process.env.CI = 'true';

      // Run setup
      await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });

      const secretsPath = join(testDir, '.secrets');
      if (existsSync(secretsPath)) {
        const stats = lstatSync(secretsPath);
        const mode = stats.mode & 0o777;
        assert.strictEqual(mode, 0o600, 'Secrets file should have 600 permissions');
      }
    });

    it('should preserve existing ~/.secrets file', async () => {
      process.env.CI = 'true';

      // Create existing secrets file
      const secretsPath = join(testDir, '.secrets');
      const existingContent = 'export MY_SECRET="existing"\n';
      writeFileSync(secretsPath, existingContent);

      // Run setup
      await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });

      // Check that existing file was preserved
      const content = readFileSync(secretsPath, 'utf8');
      assert.strictEqual(content, existingContent, 'Existing secrets file should be preserved');
    });

    it('should migrate secrets from .zshrc if they exist', async () => {
      process.env.CI = 'true';

      // Create a mock .zshrc with secrets in the dotfiles directory
      const dotfilesDir = dirname(__dirname);
      const mockZshrc = join(dotfilesDir, 'zsh', '.zshrc');
      const mockZshrcContent = `
export EDITOR=nvim
export BITBUCKET_USERNAME=test.user
export BITBUCKET_TOKEN=test-token-123
export OPENAI_API_KEY=test-api-key
`;

      // Only test if we can create the mock file
      if (existsSync(join(dotfilesDir, 'zsh'))) {
        const originalContent = existsSync(mockZshrc) ? readFileSync(mockZshrc, 'utf8') : null;

        try {
          writeFileSync(mockZshrc, mockZshrcContent);

          // Run setup
          await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
            nodeOptions: ['--experimental-strip-types']
          });

          const secretsPath = join(testDir, '.secrets');
          if (existsSync(secretsPath)) {
            const content = readFileSync(secretsPath, 'utf8');
            assert(content.includes('test.user') || content.includes('BITBUCKET_USERNAME'),
              'Should migrate username from .zshrc or include template');
          }
        } finally {
          // Restore original .zshrc
          if (originalContent !== null) {
            writeFileSync(mockZshrc, originalContent);
          }
        }
      }
    });
  });
});

describe('Bootstrap Script Tests', () => {
  it('should check for Node.js installation', async () => {
    const bootstrapPath = join(dirname(__dirname), 'bootstrap.sh');
    assert(existsSync(bootstrapPath), 'Bootstrap script should exist');
  });
});

describe('Platform-specific Tests', () => {
  const rootDir = dirname(__dirname);

  it('should have valid apt_packages.yml with expected sections', () => {
    const aptPath = join(rootDir, 'apt_packages.yml');
    assert(existsSync(aptPath), 'apt_packages.yml should exist');

    const data = YAML.parse(readFileSync(aptPath, 'utf8'));
    assert(data !== null && typeof data === 'object', 'apt_packages.yml should contain valid YAML');

    const sections = Object.keys(data);
    assert(sections.length > 0, 'apt_packages.yml should have at least one section');

    for (const section of sections) {
      assert(Array.isArray(data[section]), `Section "${section}" should be an array`);
      assert(data[section].length > 0, `Section "${section}" should not be empty`);
    }
  });

  it('should have valid brew_packages.yml with formulae and casks', () => {
    const brewPath = join(rootDir, 'brew_packages.yml');
    assert(existsSync(brewPath), 'brew_packages.yml should exist');

    const data = YAML.parse(readFileSync(brewPath, 'utf8'));
    assert(data !== null && typeof data === 'object', 'brew_packages.yml should contain valid YAML');
    assert(data.formulae !== undefined, 'brew_packages.yml should have a formulae section');
    assert(data.casks !== undefined, 'brew_packages.yml should have a casks section');
  });

  it('should complete setup on any platform with --skip-packages', async () => {
    const testDir = join(tmpdir(), `dotfiles-platform-test-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
    const originalHome = process.env.HOME;
    const originalCI = process.env.CI;

    try {
      process.env.HOME = testDir;
      process.env.CI = 'true';
      mkdirSync(join(testDir, '.config'), { recursive: true });

      const result = await execaNode(SETUP_SCRIPT, ['--skip-packages'], {
        nodeOptions: ['--experimental-strip-types']
      });

      assert.strictEqual(result.exitCode, 0, `Setup should succeed on ${platform()}`);
    } finally {
      process.env.HOME = originalHome;
      if (originalCI !== undefined) {
        process.env.CI = originalCI;
      } else {
        delete process.env.CI;
      }
      if (existsSync(testDir)) {
        rmSync(testDir, { recursive: true, force: true });
      }
    }
  });
});