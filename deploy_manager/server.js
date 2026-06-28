const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');
const chokidar = require('chokidar');
const simpleGit = require('simple-git');

// Load configuration
const configPath = path.join(__dirname, 'config.json');
let config = {
  projectPath: path.resolve(__dirname, '..'),
  buildCommand: 'flutter build windows --release',
  port: 3000,
  debounceMs: 2000,
  autoOpenBrowser: false
};

if (fs.existsSync(configPath)) {
  try {
    const userConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    config = { ...config, ...userConfig };
  } catch (error) {
    console.error('Failed to load config.json:', error.message);
  }
}

const app = express();
const PORT = config.port;

// State management
let buildState = {
  status: 'idle', // idle, building, success, error
  lastBuild: null,
  lastError: null,
  isWatching: false,
  currentLogs: []
};

let watcher = null;
let buildTimeout = null;
const git = simpleGit(config.projectPath);

// WebSocket server for real-time updates
const wss = new WebSocket.Server({ noServer: true });
const clients = new Set();

wss.on('connection', (ws) => {
  clients.add(ws);
  console.log('Client connected. Total clients:', clients.size);
  
  // Send current state to new client
  ws.send(JSON.stringify({
    type: 'state',
    data: buildState
  }));
  
  ws.on('close', () => {
    clients.delete(ws);
    console.log('Client disconnected. Total clients:', clients.size);
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
    clients.delete(ws);
  });
});

// Broadcast to all connected clients
function broadcast(type, data) {
  const message = JSON.stringify({ type, data });
  clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      try {
        client.send(message);
      } catch (error) {
        console.error('Failed to send to client:', error);
      }
    }
  });
}

// Update state and broadcast
function updateState(updates) {
  buildState = { ...buildState, ...updates };
  broadcast('state', buildState);
}

// Add log and broadcast
function addLog(message, type = 'info') {
  const logEntry = {
    timestamp: new Date().toISOString(),
    message,
    type // info, success, error, warning
  };
  buildState.currentLogs.push(logEntry);
  broadcast('log', logEntry);
}

// Execute build command
function executeBuild() {
  return new Promise((resolve, reject) => {
    updateState({ 
      status: 'building', 
      lastError: null,
      currentLogs: []
    });
    
    addLog(`Starting build: ${config.buildCommand}`, 'info');
    addLog(`Working directory: ${config.projectPath}`, 'info');
    
    const startTime = Date.now();
    
    const buildProcess = exec(
      config.buildCommand,
      { 
        cwd: config.projectPath,
        maxBuffer: 10 * 1024 * 1024 // 10MB buffer
      }
    );
    
    buildProcess.stdout.on('data', (data) => {
      const lines = data.toString().split('\n').filter(line => line.trim());
      lines.forEach(line => addLog(line, 'info'));
    });
    
    buildProcess.stderr.on('data', (data) => {
      const lines = data.toString().split('\n').filter(line => line.trim());
      lines.forEach(line => addLog(line, 'warning'));
    });
    
    buildProcess.on('close', (code) => {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      
      if (code === 0) {
        addLog(`✅ Build completed successfully in ${duration}s`, 'success');
        updateState({
          status: 'success',
          lastBuild: new Date().toISOString()
        });
        resolve({ success: true, duration });
      } else {
        const errorMsg = `Build failed with exit code ${code}`;
        addLog(`❌ ${errorMsg}`, 'error');
        updateState({
          status: 'error',
          lastError: errorMsg
        });
        reject(new Error(errorMsg));
      }
    });
    
    buildProcess.on('error', (error) => {
      addLog(`❌ Build process error: ${error.message}`, 'error');
      updateState({
        status: 'error',
        lastError: error.message
      });
      reject(error);
    });
  });
}

// Get Git status
async function getGitStatus() {
  try {
    const status = await git.status();
    const log = await git.log({ maxCount: 1 });
    
    return {
      branch: status.current,
      ahead: status.ahead,
      behind: status.behind,
      modified: status.modified.length,
      created: status.created.length,
      deleted: status.deleted.length,
      lastCommit: log.latest ? {
        hash: log.latest.hash.substring(0, 7),
        message: log.latest.message,
        author: log.latest.author_name,
        date: log.latest.date
      } : null
    };
  } catch (error) {
    console.error('Git status error:', error.message);
    return null;
  }
}

// Start file watcher
function startWatcher() {
  if (watcher) {
    return { success: false, message: 'Watcher already running' };
  }
  
  const watchPaths = [
    path.join(config.projectPath, 'lib/**/*.dart'),
    path.join(config.projectPath, 'pubspec.yaml'),
    path.join(config.projectPath, 'windows/**/*'),
    path.join(config.projectPath, 'assets/**/*')
  ];
  
  watcher = chokidar.watch(watchPaths, {
    ignored: /(^|[\/\\])\../, // ignore dotfiles
    persistent: true,
    ignoreInitial: true
  });
  
  watcher.on('change', (filepath) => {
    const relativePath = path.relative(config.projectPath, filepath);
    addLog(`📝 File changed: ${relativePath}`, 'info');
    
    // Debounce: wait for more changes
    if (buildTimeout) {
      clearTimeout(buildTimeout);
    }
    
    buildTimeout = setTimeout(() => {
      addLog('⏳ Triggering auto-build...', 'info');
      executeBuild().catch(error => {
        console.error('Auto-build failed:', error);
      });
    }, config.debounceMs);
  });
  
  watcher.on('error', error => {
    addLog(`⚠️ Watcher error: ${error.message}`, 'error');
  });
  
  updateState({ isWatching: true });
  addLog('👁️ File watcher started', 'success');
  
  return { success: true, message: 'Watcher started' };
}

// Stop file watcher
function stopWatcher() {
  if (!watcher) {
    return { success: false, message: 'Watcher not running' };
  }
  
  if (buildTimeout) {
    clearTimeout(buildTimeout);
    buildTimeout = null;
  }
  
  watcher.close();
  watcher = null;
  
  updateState({ isWatching: false });
  addLog('🛑 File watcher stopped', 'info');
  
  return { success: true, message: 'Watcher stopped' };
}

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// CORS headers
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});

// Git pull & rebuild (triggered by webhook or manual)
async function gitPullAndBuild() {
  try {
    if (buildState.status === 'building') {
      addLog('⏳ Build already in progress, skipping pull.', 'warning');
      return { success: false, message: 'Build in progress' };
    }

    addLog('📥 Pulling latest changes from remote...', 'info');
    const pullResult = await git.pull();
    
    if (pullResult.summary.changes === 0 && 
        pullResult.summary.insertions === 0 && 
        pullResult.summary.deletions === 0) {
      addLog('✅ Already up to date. No rebuild needed.', 'info');
      return { success: true, message: 'Already up to date' };
    }

    addLog(`📦 Pulled: +${pullResult.summary.insertions} -${pullResult.summary.deletions} in ${pullResult.summary.changes} file(s)`, 'success');
    addLog('🔨 Triggering rebuild...', 'info');
    
    await executeBuild();
    
    // Deploy to install dir after successful build
    const installDir = process.env.LOCALAPPDATA + '\\Programs\\AI Desktop';
    const buildDir = path.join(config.projectPath, 'build', 'windows', 'x64', 'runner', 'Release');
    
    if (fs.existsSync(installDir) && fs.existsSync(buildDir)) {
      // Kill running app first
      try {
        exec('taskkill /F /IM ai_desktop.exe', () => {});
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (_) {}
      
      // Copy files
      exec(`xcopy /E /Y /I "${buildDir}\\*" "${installDir}\\"`, (err) => {
        if (!err) {
          addLog('🚀 Deployed to install folder!', 'success');
          // Restart app
          exec(`start "" "${installDir}\\ai_desktop.exe"`);
          addLog('✅ App restarted!', 'success');
        }
      });
    }
    
    return { success: true, message: 'Pull + rebuild completed' };
  } catch (error) {
    addLog(`❌ Git pull failed: ${error.message}`, 'error');
    return { success: false, message: error.message };
  }
}

// Git poll interval (check for remote changes every N seconds)
let gitPollInterval = null;

function startGitPoll(intervalSec = 30) {
  if (gitPollInterval) return;
  
  gitPollInterval = setInterval(async () => {
    try {
      await git.fetch();
      const status = await git.status();
      if (status.behind > 0) {
        addLog(`🔔 Remote has ${status.behind} new commit(s). Auto-pulling...`, 'info');
        await gitPullAndBuild();
      }
    } catch (error) {
      // Silent fail on poll
    }
  }, intervalSec * 1000);
  
  addLog(`🔄 Git auto-poll started (every ${intervalSec}s)`, 'success');
}

function stopGitPoll() {
  if (gitPollInterval) {
    clearInterval(gitPollInterval);
    gitPollInterval = null;
    addLog('🛑 Git auto-poll stopped', 'info');
  }
}

// API Routes
app.get('/api/status', async (req, res) => {
  try {
    const gitStatus = await getGitStatus();
    res.json({
      ...buildState,
      git: gitStatus,
      config: {
        projectPath: config.projectPath,
        buildCommand: config.buildCommand,
        debounceMs: config.debounceMs
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/build', async (req, res) => {
  try {
    if (buildState.status === 'building') {
      return res.status(409).json({ 
        error: 'Build already in progress' 
      });
    }
    
    // Don't wait for build to complete, return immediately
    executeBuild().catch(error => {
      console.error('Build error:', error);
    });
    
    res.json({ 
      success: true, 
      message: 'Build started',
      status: 'building'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/watch/start', (req, res) => {
  try {
    const result = startWatcher();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/watch/stop', (req, res) => {
  try {
    const result = stopWatcher();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/logs/clear', (req, res) => {
  try {
    buildState.currentLogs = [];
    broadcast('logs_cleared', {});
    res.json({ success: true, message: 'Logs cleared' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    clients: clients.size
  });
});

// Webhook endpoint — call this from GitHub/Gitea/etc. on push
// POST /api/webhook/push
app.post('/api/webhook/push', async (req, res) => {
  try {
    addLog('🪝 Webhook received! Starting redeploy...', 'info');
    const result = await gitPullAndBuild();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Manual redeploy (git pull + rebuild) — like Easypanel's "Redeploy" button
app.post('/api/redeploy', async (req, res) => {
  try {
    addLog('🔄 Manual redeploy triggered...', 'info');
    const result = await gitPullAndBuild();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start/stop git polling (auto-check for remote changes)
app.post('/api/git-poll/start', (req, res) => {
  const interval = req.body?.interval || 30;
  startGitPoll(interval);
  res.json({ success: true, message: `Git polling started (every ${interval}s)` });
});

app.post('/api/git-poll/stop', (req, res) => {
  stopGitPoll();
  res.json({ success: true, message: 'Git polling stopped' });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`\n🚀 Deploy Manager running at http://localhost:${PORT}`);
  console.log(`📁 Project: ${config.projectPath}`);
  console.log(`🔨 Build command: ${config.buildCommand}`);
  console.log(`⏱️  Debounce: ${config.debounceMs}ms`);
  console.log(`\n👉 Open http://localhost:${PORT} in your browser\n`);
  
  // Auto-open browser if configured
  if (config.autoOpenBrowser) {
    const opener = process.platform === 'win32' ? 'start' : 
                   process.platform === 'darwin' ? 'open' : 'xdg-open';
    exec(`${opener} http://localhost:${PORT}`);
  }
});

// Handle WebSocket upgrade
server.on('upgrade', (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\n🛑 Shutting down gracefully...');
  
  if (watcher) {
    stopWatcher();
  }
  
  clients.forEach(client => {
    client.close();
  });
  
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
});