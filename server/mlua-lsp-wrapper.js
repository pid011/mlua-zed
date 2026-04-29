"use strict";

const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");
const url = require("url");

const [, , serverPathArg, workspaceRootArg] = process.argv;

if (!serverPathArg || !workspaceRootArg) {
  console.error("Usage: mlua-lsp-wrapper.js <languageServer.js> <workspace-root>");
  process.exit(1);
}

const serverPath = path.resolve(serverPathArg);
const workspaceRoot = path.resolve(workspaceRootArg);
const extensionRoot = path.resolve(path.dirname(serverPath), "../../..");

const server = childProcess.fork(serverPath, ["--node-ipc"], {
  cwd: extensionRoot,
  env: process.env,
  silent: true,
});

server.stdout.on("data", (chunk) => process.stderr.write(chunk));
server.stderr.on("data", (chunk) => process.stderr.write(chunk));
server.on("exit", (code, signal) => {
  if (signal) {
    process.stderr.write(`mLua language server exited with signal ${signal}\n`);
  } else if (code !== 0) {
    process.stderr.write(`mLua language server exited with code ${code}\n`);
  }
  process.exit(code ?? 1);
});

process.on("exit", () => {
  if (!server.killed) {
    server.kill();
  }
});

createMessageReader(process.stdin, (message) => {
  if (message && message.method === "initialize" && message.params) {
    const generatedOptions = buildInitializationOptions(workspaceRoot, extensionRoot);
    const configuredOptions = parseInitializationOptions(message.params.initializationOptions);

    message.params.initializationOptions = JSON.stringify(
      deepMerge(generatedOptions, configuredOptions),
    );
  }

  server.send(message);
});

server.on("message", (message) => {
  writeMessage(process.stdout, message);
});

function createMessageReader(stream, onMessage) {
  let buffer = Buffer.alloc(0);

  stream.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);

    while (true) {
      const headerEnd = buffer.indexOf("\r\n\r\n");
      if (headerEnd === -1) {
        return;
      }

      const header = buffer.slice(0, headerEnd).toString("ascii");
      const match = /Content-Length:\s*(\d+)/i.exec(header);
      if (!match) {
        throw new Error(`Invalid LSP message header: ${header}`);
      }

      const contentLength = Number(match[1]);
      const messageStart = headerEnd + 4;
      const messageEnd = messageStart + contentLength;
      if (buffer.length < messageEnd) {
        return;
      }

      const json = buffer.slice(messageStart, messageEnd).toString("utf8");
      buffer = buffer.slice(messageEnd);
      onMessage(JSON.parse(json));
    }
  });
}

function writeMessage(stream, message) {
  const json = JSON.stringify(message);
  const body = Buffer.from(json, "utf8");
  stream.write(`Content-Length: ${body.length}\r\n\r\n`);
  stream.write(body);
}

function buildInitializationOptions(root, extensionRootPath) {
  return {
    documentItems: findMluaDocuments(root),
    entryItems: [],
    modules: predefines(extensionRootPath, "modules"),
    globalVariables: predefines(extensionRootPath, "globalVariables"),
    globalFunctions: predefines(extensionRootPath, "globalFunctions"),
    capabilities: {
      completionCapability: {
        codeBlockScriptSnippetCompletion: true,
        codeBlockBTNodeSnippetCompletion: true,
        codeBlockComponentSnippetCompletion: true,
        codeBlockEventSnippetCompletion: true,
        codeBlockMethodSnippetCompletion: true,
        codeBlockHandlerSnippetCompletion: true,
        codeBlockItemSnippetCompletion: true,
        codeBlockLogicSnippetCompletion: true,
        codeBlockPropertySnippetCompletion: true,
        codeBlockStateSnippetCompletion: true,
        codeBlockStructSnippetCompletion: true,
        attributeCompletion: true,
        eventMethodCompletion: true,
        overrideMethodCompletion: true,
        overridePropertyCompletion: true,
        annotationCompletion: true,
        keywordCompletion: true,
        luaCodeCompletion: true,
        commitCharacterSupport: true,
      },
      definitionCapability: {},
      diagnosticCapability: {
        needExtendsDiagnostic: true,
        notEqualsNameDiagnostic: true,
        duplicateLocalDiagnostic: true,
        introduceGlobalVariableDiagnostic: true,
        parseErrorDiagnostic: true,
        annotationParseErrorDiagnostic: true,
        unavailableAttributeDiagnostic: true,
        unavailableTypeDiagnostic: true,
        unresolvedMemberDiagnostic: true,
        unresolvedSymbolDiagnostic: true,
        assignTypeMismatchDiagnostic: true,
        parameterTypeMismatchDiagnostic: true,
        deprecatedDiagnostic: true,
        overrideMemberMismatchDiagnostic: true,
        unavailableOptionalParameterDiagnostic: true,
        unavailableParameterNameDiagnostic: true,
        invalidAttributeArgumentDiagnostic: true,
        notAllowPropertyDefaultValueDiagnostic: true,
        assignToReadonlyDiagnostic: true,
        needPropertyDefaultValueDiagnostic: true,
        notEnoughArgumentDiagnostic: true,
        tooManyArgumentDiagnostic: true,
        duplicateMemberDiagnostic: true,
        cannotOverrideMemberDiagnostic: true,
        tableKeyTypeMismatchDiagnostic: true,
        duplicateAttributeDiagnostic: true,
        invalidEventHandlerParameterDiagnostic: true,
        unavailablePropertyNameDiagnostic: true,
        annotationTypeNotFoundDiagnostic: true,
        annotationParamNotFoundDiagnostic: true,
        unbalancedAssignmentDiagnostic: true,
        unexpectedReturnDiagnostic: true,
        needReturnDiagnostic: true,
        duplicateParamDiagnostic: true,
        returnTypeMismatchDiagnostic: true,
        expectedReturnValueDiagnostic: true,
      },
      documentSymbolCapability: {},
      hoverCapability: {},
      referenceCapability: {},
      semanticTokensCapability: {},
      signatureHelpCapability: {},
      typeDefinitionCapability: {},
      renameCapability: {},
      inlayHintCapability: {},
      documentFormattingCapability: {},
      documentRangeFormattingCapability: {},
    },
    profileMode: false,
    stopwatch: false,
  };
}

function parseInitializationOptions(value) {
  if (!value) {
    return {};
  }

  if (typeof value === "string") {
    try {
      return JSON.parse(value);
    } catch {
      return {};
    }
  }

  if (typeof value === "object") {
    return value;
  }

  return {};
}

function deepMerge(base, overrides) {
  const merged = { ...base };

  for (const [key, value] of Object.entries(overrides)) {
    if (
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      merged[key] &&
      typeof merged[key] === "object" &&
      !Array.isArray(merged[key])
    ) {
      merged[key] = deepMerge(merged[key], value);
    } else {
      merged[key] = value;
    }
  }

  return merged;
}

function predefines(root, method) {
  const moduleAlias = require(path.join(root, "node_modules", "module-alias"));
  moduleAlias.addAliases({
    "@common": path.join(root, "scripts", "common", "out"),
    "@protocol": path.join(root, "scripts", "protocol", "out"),
    "@parser": path.join(root, "scripts", "parser", "out"),
    "@predefines": path.join(root, "scripts", "predefines", "out"),
  });

  const { Predefines } = require("@predefines");
  return Predefines[method]();
}

function findMluaDocuments(root) {
  const documents = [];
  walk(root, (filePath) => {
    if (!filePath.endsWith(".mlua")) {
      return;
    }

    try {
      documents.push({
        uri: pathToFileUri(filePath),
        languageId: "mlua",
        version: 0,
        text: fs.readFileSync(filePath, "utf8"),
      });
    } catch (error) {
      process.stderr.write(`Failed to read ${filePath}: ${error.message}\n`);
    }
  });
  return documents;
}

function walk(directory, onFile) {
  let entries;
  try {
    entries = fs.readdirSync(directory, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (shouldSkipDirectory(entry.name)) {
        continue;
      }
      walk(fullPath, onFile);
    } else if (entry.isFile()) {
      onFile(fullPath);
    }
  }
}

function shouldSkipDirectory(name) {
  return name === ".git" || name === "node_modules" || name === ".zed" || name === "target";
}

function pathToFileUri(filePath) {
  return url.pathToFileURL(path.resolve(filePath)).href;
}
