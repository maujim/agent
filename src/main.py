import os, sys
import json
import inspect

from typing import get_type_hints, get_origin
from dotenv import load_dotenv
from pathlib import Path
from functools import wraps


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

MODEL = "gemini-2.0-flash"


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
        result = func(*args, **kwargs)

        # render result
        ret_hint = hints.get("return")
        origin = get_origin(ret_hint)
        is_structured = (
            origin in (dict, list)
            or ret_hint in (dict, list)
            or isinstance(result, (dict, list))
        )

        if is_structured:
            try:
                preview = json.dumps(result, indent=2)
            except Exception:
                preview = str(result)
        else:
            preview = str(result)

        if len(preview) > 400:
            preview = preview[:400] + "…"

        console.print(Text(preview, style="dim"))

        return result

    return wrapper


@tool_ui
def read_file(path: str) -> str:
    """Read a text file from the project directory.

    Args:
        path: Relative path to a text file.
    """

    base = Path.cwd().resolve()
    target = (base / path).resolve()

    if not str(target).startswith(str(base)):
        return "error: path escapes project directory"

    if not target.exists() or not target.is_file():
        return "error: file not found"

    return target.read_text(encoding="utf-8")


@tool_ui
def list_files(list_file_path: str = "file_list.txt") -> str:
    """
    Reads a file containing a list of files in the project.
    The list should be manually maintained.

    Args:
        list_file_path: The path to the file containing the list of files.
    """
    try:
        with open(list_file_path, "r") as f:
            files = f.read()
        return files
    except FileNotFoundError:
        return "Error: file_list.txt not found. Please create this file with a list of project files."


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
                            temperature=0.7,
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

            console.print(Text("gemini: ", style="bold yellow"), Text(assistant_text))

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
