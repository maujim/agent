#!/usr/bin/env python3
"""
RPC Server for Lagos NeoVim Plugin
Provides JSON-RPC interface between NeoVim and the Lagos AI Agent
"""

import asyncio
import json
import os
import sys
import traceback
from pathlib import Path
from typing import Any
from typing import Dict
from typing import List
from typing import Optional

# Add the src directory to the path to import the agent
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

try:
    from dotenv import load_dotenv
    from google import genai
    from google.genai import types

    from main import Agent
    from main import is_path_permitted
    from main import tool_ui
except ImportError as e:
    print(f"Import error: {e}", file=sys.stderr)
    sys.exit(1)


class LagosRPCServer:
    """JSON-RPC server for Lagos NeoVim integration"""

    def __init__(self, project_root: Optional[str] = None):
        # Load environment variables
        load_dotenv()

        # Setup environment
        if not os.getenv("GOOGLE_API_KEY"):
            print("Error: GOOGLE_API_KEY not found in environment", file=sys.stderr)
            sys.exit(1)

        # Initialize client and agent
        self.client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
        self.agent = Agent(self.client)

        # Store additional context for NeoVim integration
        self.project_root = project_root or os.getcwd()
        self.current_buffer = None
        self.visual_selection = None

        # Add NeoVim-specific tools
        self._add_neovim_tools()

    def _add_neovim_tools(self):
        """Add NeoVim-specific tools to the agent"""

        @tool_ui
        def get_buffer_content(bufnr: int) -> tuple[str, list]:
            """Get the content of a NeoVim buffer.

            Args:
                bufnr: Buffer number
            """
            # This will be called from NeoVim with actual buffer content
            # For now, return a placeholder that NeoVim will fill
            return f"Buffer {bufnr} content requested", []

        @tool_ui
        def get_visual_selection() -> tuple[str, list]:
            """Get the visually selected text in NeoVim."""
            # This will be called from NeoVim with actual selection
            return "Visual selection requested", []

        @tool_ui
        def apply_edit(bufnr: int, edits: List[Dict]) -> str:
            """Apply edits to a NeoVim buffer.

            Args:
                bufnr: Buffer number to edit
                edits: List of edit operations with line ranges and text
            """
            # Return edit instructions for NeoVim to apply
            edit_instructions = []
            for edit in edits:
                if edit.get("type") == "replace":
                    edit_instructions.append(
                        f"Replace lines {edit['start_line']}-{edit['end_line']}: {edit['text']}"
                    )
                elif edit.get("type") == "insert":
                    edit_instructions.append(
                        f"Insert at line {edit['line']}: {edit['text']}"
                    )
                elif edit.get("type") == "delete":
                    edit_instructions.append(
                        f"Delete lines {edit['start_line']}-{edit['end_line']}"
                    )

            return "Edit operations to apply:\n" + "\n".join(edit_instructions)

        # Add tools to agent
        self.agent._tools.extend([get_buffer_content, get_visual_selection, apply_edit])

    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle an incoming JSON-RPC request"""
        try:
            method = request.get("method")
            params = request.get("params", {})
            request_id = request.get("id")

            if method == "chat":
                return self._handle_chat(params, request_id)
            elif method == "ask":
                return self._handle_ask(params, request_id)
            elif method == "explain":
                return self._handle_explain(params, request_id)
            elif method == "fix":
                return self._handle_fix(params, request_id)
            elif method == "refactor":
                return self._handle_refactor(params, request_id)
            elif method == "set_context":
                return self._handle_set_context(params, request_id)
            elif method == "get_history":
                return self._handle_get_history(params, request_id)
            elif method == "clear_history":
                return self._handle_clear_history(params, request_id)
            else:
                return {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"},
                }

        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": request.get("id"),
                "error": {
                    "code": -32603,
                    "message": "Internal error",
                    "data": traceback.format_exc(),
                },
            }

    def _handle_chat(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Handle a chat message"""
        message = params.get("message", "")
        if not message:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": "Message is required"},
            }

        # Add context if available
        if self.current_buffer:
            message = f"[Current buffer: {self.current_buffer['name']}]\n{message}"

        if self.visual_selection:
            message = f"[Selected text:\n{self.visual_selection}\n]\n{message}"

        # Add to history
        self.agent.history.append(
            types.Content(
                role="user",
                parts=[types.Part(text=message)],
            )
        )

        # Generate response
        try:
            response = self.client.models.generate_content(
                model="gemini-2.5-flash",
                contents=self.agent.history,
                config=types.GenerateContentConfig(
                    max_output_tokens=2048,
                    temperature=0.95,
                    tools=self.agent._tools,
                ),
            )

            if not response.candidates:
                return {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": {"response": "No response from AI", "type": "text"},
                }

            # Extract text response
            parts = response.candidates[0].content.parts
            response_text = ""
            tool_calls = []

            for part in parts:
                if part.text:
                    response_text += part.text
                elif part.function_call:
                    tool_calls.append(
                        {
                            "name": part.function_call.name,
                            "args": dict(part.function_call.args),
                        }
                    )

            # Add to history
            self.agent.history.append(
                types.Content(
                    role="model",
                    parts=[types.Part(text=response_text)],
                )
            )

            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "response": response_text,
                    "type": "text",
                    "tool_calls": tool_calls,
                },
            }

        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32603, "message": str(e)},
            }

    def _handle_ask(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Handle a quick ask request"""
        return self._handle_chat(params, request_id)

    def _handle_explain(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Handle code explanation request"""
        code = params.get("code", "")
        language = params.get("language", "unknown")

        message = f"Please explain this {language} code:\n\n{code}"
        return self._handle_chat({"message": message}, request_id)

    def _handle_fix(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Handle code fix request"""
        code = params.get("code", "")
        error = params.get("error", "")
        language = params.get("language", "unknown")

        message = f"Please fix this {language} code"
        if error:
            message += f" that has this error: {error}"
        message += f":\n\n{code}"

        return self._handle_chat({"message": message}, request_id)

    def _handle_refactor(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Handle code refactor request"""
        code = params.get("code", "")
        instruction = params.get("instruction", "refactor this code")
        language = params.get("language", "unknown")

        message = f"Please refactor this {language} code to {instruction}:\n\n{code}"
        return self._handle_chat({"message": message}, request_id)

    def _handle_set_context(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Set context (current buffer, selection, etc.)"""
        self.current_buffer = params.get("buffer")
        self.visual_selection = params.get("selection")

        return {"jsonrpc": "2.0", "id": request_id, "result": {"status": "ok"}}

    def _handle_get_history(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Get chat history"""
        history = []
        for content in self.agent.history:
            history.append(
                {
                    "role": content.role,
                    "text": "".join(part.text for part in content.parts if part.text),
                }
            )

        return {"jsonrpc": "2.0", "id": request_id, "result": {"history": history}}

    def _handle_clear_history(self, params: Dict, request_id: Any) -> Dict[str, Any]:
        """Clear chat history"""
        self.agent.history = []
        return {"jsonrpc": "2.0", "id": request_id, "result": {"status": "ok"}}

    def run(self):
        """Run the RPC server (read from stdin, write to stdout)"""
        try:
            for line in sys.stdin:
                if not line.strip():
                    continue

                try:
                    request = json.loads(line)
                    response = self.handle_request(request)
                    print(json.dumps(response))
                    sys.stdout.flush()
                except json.JSONDecodeError as e:
                    error_response = {
                        "jsonrpc": "2.0",
                        "id": None,
                        "error": {"code": -32700, "message": f"Parse error: {str(e)}"},
                    }
                    print(json.dumps(error_response))
                    sys.stdout.flush()

        except KeyboardInterrupt:
            pass
        except Exception as e:
            print(f"Server error: {e}", file=sys.stderr)
            sys.exit(1)


def main():
    """Entry point for the RPC server"""
    import argparse

    parser = argparse.ArgumentParser(description="Lagos NeoVim RPC Server")
    parser.add_argument("--project-root", help="Project root directory")
    args = parser.parse_args()

    server = LagosRPCServer(args.project_root)
    server.run()


if __name__ == "__main__":
    main()
