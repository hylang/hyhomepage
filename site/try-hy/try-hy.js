window.onload = async function() {'use strict';

let E = x => document.getElementById(x)

let pyodide = null

let startup = async function()
   {pyodide = await loadPyodide()
    await pyodide.loadPackage('micropip')
    await pyodide.runPythonAsync(`
        import sys, ast, pyodide, micropip, js
        from pathlib import Path
        from pyodide.http import pyfetch
        E = js.document.getElementById

        # Fetch Hy and install its dependencies.
        await (await pyfetch('/try-hy/hy-for-pyodide.tar.gz')).unpack_archive()
        for dependency in ast.parse(Path("setup.py").read_text()).body[0].value.elts:
             await micropip.install(dependency.value)
        import hy

        # Send Python's STDOUT and STDERR to our console.
        class ConsoleWriter:
            def write(self, text):
                if not text:
                    return 0
                E('console-input-chunk').insertAdjacentText('beforebegin', text)
                E('console-input').scrollIntoView()
                return len(text)
            def flush(self):
                pass
        sys.stdout = sys.stderr = ConsoleWriter()`)

    await restart_repl()

    E('console-input-chunk').style.display = 'inline-block'
    E('console-input').focus()}

let restart_repl = async () => await pyodide.runPythonAsync(`
    # Clear the console log. (Don't clear history, because the
    # old entries could still be useful.)
    inp = E('console-input-chunk')
    E('console').textContent = ''
    E('console').append(inp)

    # Set 'repl' to a new REPL object.
    repl = hy.REPL(
        allow_incomplete = False,
        spy = E('spy').checked)
    print(repl.banner())
    hy.errors.filtered_hy_exceptions().__enter__()`)

E('restart').addEventListener('click', restart_repl)

E('console').addEventListener('submit', function(event)
  // Send the input to the REPL.
   {event.preventDefault()
    let input = E('console-input').value
    if (!history.length || input !== history[history.length - 1])
       {history.push(input)
        history_ix = history.length}
    E('console-input').value = ''
    E('console-input-chunk').insertAdjacentText('beforebegin',
        '=> ' + input + '\n')
    pyodide.globals.set('input', input)
    pyodide.runPython('repl.runsource(input)')})

let history = []
  // A list of past inputs to the REPL.
let history_ix = null
  // The index of the currently selected history entry.
let new_input = ''
  // Acts like a final, most recent history entry that can be
  // changed, while the other entries remain fixed. It's selected
  // with `history_ix` set to `history.length`.

E('console-input').addEventListener('keydown', function(event)
  // The arrow keys scroll through history.
   {if (event.code === 'ArrowUp' || event.code === 'ArrowDown')
       {event.preventDefault()
        if (!history.length)
            return
        if (history_ix === history.length)
           {if (event.code === 'ArrowDown')
                return
            new_input = E('console-input').value}
        let i = history_ix + (event.code === 'ArrowUp' ? -1 : 1)
        if (i < 0)
            return
        history_ix = i
        E('console-input').value = (history_ix === history.length
          ? new_input
          : history[history_ix])}})

E('loading-message').textContent = 'Loading…'
try
   {await startup()
    E('loading-message').remove()}
catch (error)
   {E('loading-message').textContent = error.toString()}

}
