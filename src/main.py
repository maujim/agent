import inspect
import json
import os
import sys
from functools import wraps
from pathlib import Path
from typing import get_origin
from typing import get_type_hints

import dspy

from dotenv import load_dotenv

from google import genai
from google.genai import types
from rich.console import Console
from rich.prompt import Prompt
from rich.text import Text

load_dotenv()

API_KEY = os.getenv("GOOGLE_API_KEY")
if not API_KEY:
    raise RuntimeError("missing GOOGLE_API_KEY in .env")

client = genai.Client(api_key=API_KEY)

console = Console()

MODEL = "gemini-2.5-flash"


def tool_ui(func):
    """
    Simple decorator for Gemini tools that logs calls/results to Rich UI.
    Preserves type hints and docstring for schema detection.
    """
    sig = inspect.signature(func)
    hints = get_type_hints(func)
    doc = inspect.getdoc(func) or ""

    tool_meta = {
        "signature": sig,
        "hints": hints,
        "doc": doc,
        "name": func.__name__,
    }
    func.__tool_meta__ = tool_meta

    @wraps(func)
    def wrapper(*args, **kwargs):
        # bind args
        bound = sig.bind_partial(*args, **kwargs)
        bound.apply_defaults()

        arg_str = ", ".join(f"{k}={v!r}" for k, v in bound.arguments.items())
        console.print(
            "[bold green]tool[/bold green]:", Text(f"{func.__name__}({arg_str})")
        )

        # execute
        try:
            msg, result = func(*args, **kwargs)
            console.print(Text(msg), style="dim")
        except Exception as err:
            error_msg = f"tool call failed with error: {str(err)}"
            result = error_msg
            truncated_err = str(err)[:280]
            console.print(Text("Error", style="red"), Text(truncated_err))

        return result

    return wrapper


def is_path_permitted(path: str):
    """Check whether a path is within the project directory.

    Args:
        path: Path to check (can be relative or absolute)

    Raises:
        PermissionError: If path escapes the project directory
    """
    base = Path.cwd().resolve()
    target = Path(path).resolve()

    if not str(target).startswith(str(base)):
        raise PermissionError("error: path escapes project directory")

    return target


@tool_ui
def read_file(path: str) -> tuple[str, list]:
    """Read a text file from the project directory.

    Args:
        path: Path to a text file (can be relative or absolute).
    """
    target = is_path_permitted(path)
    result = target.read_text(encoding="utf-8")

    num_lines = result.count("\n") + 1 if result.strip() else 0
    msg = f"Read {num_lines} lines"
    return msg, [result]


@tool_ui
def list_files(path: str) -> tuple[str, list]:
    """
    List all files and directories in a given path.

    Args:
        path: Path to the directory to list (can be relative or absolute).
    """
    target_dir = is_path_permitted(path)
    entries = os.listdir(target_dir)

    msg = f"Listed {len(entries)}"
    return msg, entries


@tool_ui
def edit_file(path: str, instructions: str) -> str:
    """
    Provides instructions to the user on how to edit a file.
    This tool cannot directly edit files.

    Args:
        path: The path to the file to be edited.
        instructions: Instructions on how to edit the file.
    """
    return f"To edit the file '{path}', follow these instructions:\n{instructions}\n\nNote: I cannot directly edit the file. You need to manually make these changes."


class Agent:
    def __init__(self, client):
        self.client = client
        self.history = []

        self._tools = [
            # types.Tool(code_execution=types.ToolCodeExecution()),
            read_file,
            list_files,
        ]

    def run(self):
        console.print("[bold cyan]chat with gemini (ctrl-c to quit)[/bold cyan]")

        while True:
            try:
                user_input = Prompt.ask("[bold blue]you[/bold blue]")
            except (EOFError, KeyboardInterrupt):
                console.print("\n[dim]bye[/dim]")
                return

            if not user_input.strip():
                continue

            self.history.append(
                types.Content(
                    role="user",
                    parts=[types.Part(text=user_input)],
                )
            )

            try:
                response: types.GenerateContentResponse = (
                    self.client.models.generate_content(
                        model=MODEL,
                        contents=self.history,
                        config=types.GenerateContentConfig(
                            max_output_tokens=1024,
                            temperature=0.95,
                            tools=self._tools,
                            # automatic_function_calling=types.AutomaticFunctionCallingConfig(
                            #     disable=True
                            # ),
                        ),
                    )
                )
            except Exception as e:
                console.print(f"[bold red]error[/bold red]: {e}")
                continue

            if not response.candidates:
                console.print("[yellow]empty response[/yellow]")
                continue

            # if fc := response.function_calls:
            #     num_tools = len(fc)
            #     console.print(f"[green]tool_call[/green]:")
            #     for ff in fc:
            #         item: types.FunctionCall = ff
            #         console.print(item)

            parts = response.candidates[0].content.parts

            assistant_text = ""
            for part in parts:
                if part.text:
                    assistant_text += part.text

            if not assistant_text.strip():
                console.print("[yellow]no text output[/yellow]")
                continue

            console.print(
                Text("gemini: ", style="bold yellow"), Text(assistant_text.rstrip())
            )

            self.history.append(
                types.Content(
                    role="model",
                    parts=[types.Part(text=assistant_text)],
                )
            )


def main():
    Agent(client).run()


if __name__ == "__main__":
    main()
