import http from "http";
import net from "net";
import { spawn } from "child_process";

const GODOT_BIN = process.env.GODOT_BIN || "/usr/bin/godot";
const WORKDIR = new URL("..", import.meta.url).pathname;
const AUTH_TOKEN = process.env.AUTH_TOKEN || "test-token";
const SERVER_READY_MARKER = "WS server listening";
const TIMEOUT_MS = 15000;

function getAvailablePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

function startMockAuthServer() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.url !== "/whoami") {
        res.writeHead(404, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: "not_found" }));
        return;
      }
      res.writeHead(200, { "content-type": "application/json" });
      res.end(
        JSON.stringify({
          address: "0x0000000000000000000000000000000000000000",
          nonce: "test-nonce",
          exp: Math.floor(Date.now() / 1000) + 3600,
          iat: Math.floor(Date.now() / 1000),
        }),
      );
    });
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolve({ server, port });
    });
  });
}

function waitForOutput(proc, marker) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timeout waiting for: ${marker}`));
    }, TIMEOUT_MS);
    proc.stdout.on("data", (chunk) => {
      const text = chunk.toString();
      if (text.includes(marker)) {
        clearTimeout(timeout);
        resolve();
      }
    });
    proc.stderr.on("data", (chunk) => {
      process.stderr.write(chunk);
    });
  });
}

async function run() {
  const wsPort = await getAvailablePort();
  const { server: mockServer, port: mockPort } = await startMockAuthServer();
  const authBaseUrl = `http://127.0.0.1:${mockPort}`;
  const serverProc = spawn(
    GODOT_BIN,
    ["--headless", "--path", "godot", "--scene", "res://ws_server.tscn"],
    {
      cwd: WORKDIR,
      env: {
        ...process.env,
        AUTH_BASE_URL: authBaseUrl,
        WS_PORT: String(wsPort),
      },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  try {
    await waitForOutput(serverProc, SERVER_READY_MARKER);
    const clientProc = spawn(
      GODOT_BIN,
      ["--headless", "--path", "godot", "--scene", "res://ws_client.tscn"],
      {
        cwd: WORKDIR,
        env: {
          ...process.env,
          AUTH_TOKEN,
          WS_URL: `ws://127.0.0.1:${wsPort}`,
        },
        stdio: ["ignore", "inherit", "inherit"],
      },
    );

    const exitCode = await new Promise((resolve) => {
      clientProc.on("exit", (code) => resolve(code ?? 1));
    });
    if (exitCode !== 0) {
      throw new Error(`Client exited with code ${exitCode}`);
    }
    console.log("Godot WS auth test passed.");
  } finally {
    serverProc.kill("SIGTERM");
    mockServer.close();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
