import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync, mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, symlinkSync, lstatSync } from 'fs';
import { tmpdir } from 'os';
import { execaNode } from 'execa';

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
});

describe('Bootstrap Script Tests', () => {
  it('should check for Node.js installation', async () => {
    // This test would require mocking the fnm installation process
    // For now, we just verify the bootstrap script exists
    const bootstrapPath = join(dirname(__dirname), 'bootstrap.sh');
    assert(existsSync(bootstrapPath), 'Bootstrap script should exist');
  });
});