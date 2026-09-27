/** Fresh connection to the user's persistent Meshy MCP; never reads/prints credentials. */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { pathToFileURL } from 'node:url';

const [tool, inputFile, outputFile, approvedCredits] = process.argv.slice(2);
const supported = new Set(['meshy_check_balance','meshy_image_to_3d','meshy_get_task_status','meshy_download_model']);
if (!supported.has(tool) || !inputFile || !outputFile) throw new Error('Usage: invoke-meshy-mcp.mjs TOOL INPUT_JSON OUTPUT_JSON [APPROVED_CREDITS]');
const args = JSON.parse(readFileSync(inputFile, 'utf8'));
if (tool === 'meshy_image_to_3d' && !(Number(approvedCredits) > 0)) throw new Error('Paid generation requires the explicitly approved credit amount.');
const codexHome = process.env.CODEX_HOME || join(homedir(), '.codex');
const installation = join(codexHome, 'tools', 'meshy-mcp-server-esir');
const sdk = join(installation, 'node_modules', '@modelcontextprotocol', 'sdk', 'dist', 'esm', 'client');
const {Client} = await import(pathToFileURL(join(sdk, 'index.js')));
const {StdioClientTransport} = await import(pathToFileURL(join(sdk, 'stdio.js')));
const client = new Client({name:'esir-asset-pipeline',version:'1.0.0'});
const transport = new StdioClientTransport({command:join(codexHome,'tools','meshy-mcp.cmd'),args:[],stderr:'pipe'});
transport.stderr?.on('data', () => {});
try {
  await client.connect(transport, {timeout:30000});
  const version = client.getServerVersion()?.version;
  if (version !== '0.5.2-esir.20260925.1') throw new Error('Unexpected MCP version; inspect its schema before submitting.');
  const result = await client.callTool({name:tool,arguments:args}, undefined, {timeout:360000});
  const output = resolve(outputFile);
  mkdirSync(dirname(output), {recursive:true});
  writeFileSync(output, JSON.stringify({tool,server_version:version,approved_credits:Number(approvedCredits)||0,result},null,2));
  const summary = result.structuredContent ?? {};
  console.log(JSON.stringify({tool,server_version:version,isError:!!result.isError,output,
    task_id:summary.task_id,status:summary.status,progress:summary.progress,
    consumed_credits:summary.consumed_credits,local_path:summary.local_path,
    file_size_bytes:summary.file_size_bytes}));
  if (result.isError) {
    console.error(result.content?.filter(c=>c.type==='text').map(c=>c.text).join('\n').slice(0,1000));
    process.exitCode=1;
  }
} finally {
  await client.close();
}
