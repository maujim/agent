import os, sys, json
import inspect

from typing import get_type_hints
from dotenv import load_dotenv
from pathlib import Path
from functools import wraps


from google import genai
from google.genai import types

from rich.console import Console
from rich.prompt import Prompt
from rich.text import Text

# ---------- setup ----------

load_dotenv()

API_KEY = os.getenv("GOOGLE_API_KEY")
if not API_KEY:
    raise RuntimeError("missing GOOGLE_API_KEY in .env")

client = genai.Client(api_key=API_KEY)

console = Console()

MODEL = "gemini-2.0-flash"

# ---------- agent ----------

def tool_ui(func, detailed=False):
    """
    Decorator for Gemini tools that logs tool calls/results to Rich UI
    without interfering with Gemini's schema inference.
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

    @wraps(func)
    def wrapper(*args, **kwargs):
        # show tool call
        arg_str = []
        arg_str.extend(repr(a) for a in args)
        arg_str.extend(f"{k}={v!r}" for k, v in kwargs.items())

        console.print(
            "[bold green]tool:[/bold green]",
            f"{func.__name__}({', '.join(arg_str)})",
        )

        result = func(*args, **kwargs)

        # show tool result (truncate aggressively)
        preview = result
        if tool_meta['hints']['return'] _____ or isinstance(result, (dict, list)):
            preview = json.dumps(result, indent=2)
        else:
            preview = str(result)

        if len(preview) > 400:
            preview = preview[:400] + "…"

        console.print(
            Text(
                preview,
                style="dim",
            )
        )

        return result

    return wrapper

@tool_ui(detailed=True)
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

            console.print(Text("gemini: ", style="bold yellow") + Text(assistant_text))

            self.history.append(
                types.Content(
                    role="model",
                    parts=[types.Part(text=assistant_text)],
                )
            )


# ---------- main ----------


def main():
    Agent(client).run()


if __name__ == "__main__":
    main()
