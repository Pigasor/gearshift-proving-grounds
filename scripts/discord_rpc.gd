extends Node
# Discord Rich Presence: shows "Playing GearShift Proving Grounds" with the car and the place on
# the player's Discord profile, on any PC where the Discord app is running (no setup, no extra DLL).
# Discord listens on a local named pipe (discord-ipc-N). Godot's file API can't open named pipes, so a
# hidden PowerShell (on every Windows PC) relays the frames between the game and the pipe. A worker
# thread does the handshake, then SET_ACTIVITY whenever the car / place changes. While Discord isn't
# running the relay just waits for it (checking every 10 s).
# The activity's title is the name of the Discord application whose id is APP_ID.

const APP_ID: String = "" # Discord Developer Portal > Applications > "GearShift Proving Grounds" > Application ID
const RETRY_S: float = 20.0

var app_id: String = APP_ID
var vehicle: Node
var _thread: Thread
var _mutex := Mutex.new()
var _quit: bool = false
var _want: Dictionary = {} # activity the game wants shown (main thread writes, worker reads)
var _sent: String = "" # JSON of the last activity sent (worker)
var _start_unix: int = 0
var _tick: float = 0.0
var _pid: int = 0 # the relay process

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if app_id == "" or OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	_start_unix = int(Time.get_unix_time_from_system())
	_thread = Thread.new()
	_thread.start(_worker)

func _exit_tree() -> void:
	if _thread:
		_mutex.lock()
		_quit = true
		_mutex.unlock()
		if _pid > 0:
			OS.kill(_pid) # ends a blocking read in the worker
		_thread.wait_to_finish()

func _process(delta: float) -> void:
	_tick -= delta
	if _thread == null or _tick > 0.0 or vehicle == null:
		return
	_tick = 3.0
	var car: String = CarDatabase.display_name(int(vehicle.current_vehicle_type), int(vehicle.current_engine_index))
	var act: Dictionary = {
		"details": car,
		"state": _place(),
		"timestamps": {"start": _start_unix},
		"assets": {"large_image": "icon", "large_text": "GearShift Proving Grounds"},
	}
	_mutex.lock()
	_want = act
	_mutex.unlock()

# Name of the nearest map area (the big map's labels), else free roam
func _place() -> String:
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	var best: String = ""
	var best_d: float = 700.0
	var fm: GDScript = load("res://scripts/full_map.gd")
	for a in fm.get_script_constant_map()["AREAS"]:
		var d: float = p.distance_to(a[1])
		if d < best_d:
			best_d = d
			best = a[0]
	return tr(best) if best != "" else tr("Serbest sürüş")

# ---------------------------------------------------------------- worker thread
# Waits (every 10 s, without touching other programs' pipes) until Discord's pipe exists, connects
# and then copies bytes both ways; quits when the game is gone.
const RELAY_PS := """
$game = %d
$p = $null
while ($p -eq $null) {
  if (-not (Get-Process -Id $game -ErrorAction SilentlyContinue)) { exit 0 }
  foreach ($nm in [System.IO.Directory]::GetFiles('\\\\.\\pipe\\')) {
    $n = [System.IO.Path]::GetFileName($nm)
    if ($p -eq $null -and $n -like 'discord-ipc-*') {
      try { $c = New-Object System.IO.Pipes.NamedPipeClientStream('.', $n, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous); $c.Connect(500); $p = $c } catch { }
    }
  }
  if ($p -eq $null) { Start-Sleep -Seconds 10 }
}
$i = [Console]::OpenStandardInput()
$o = [Console]::OpenStandardOutput()
$a = $i.CopyToAsync($p)
$b = $p.CopyToAsync($o)
[void][System.Threading.Tasks.Task]::WaitAny(@($a, $b))
"""

func _worker() -> void:
	while not _stopping():
		var io: FileAccess = _connect() # blocks until Discord is there (the relay waits for it)
		if io == null:
			_sleep(RETRY_S)
			continue
		_sent = ""
		while not _stopping():
			_mutex.lock()
			var want: Dictionary = _want.duplicate(true)
			_mutex.unlock()
			var js: String = JSON.stringify(want)
			if not want.is_empty() and js != _sent:
				var cmd := {"cmd": "SET_ACTIVITY", "args": {"pid": OS.get_process_id(), "activity": want}, "nonce": str(Time.get_ticks_usec())}
				if not _send(io, 1, cmd) or _recv(io).is_empty():
					break # Discord closed: start over later
				_sent = js
			_sleep(1.0)
		_close()
		_sleep(RETRY_S)

func _stopping() -> bool:
	_mutex.lock()
	var q: bool = _quit
	_mutex.unlock()
	return q

func _sleep(s: float) -> void:
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end and not _stopping():
		OS.delay_msec(100)

func _connect() -> FileAccess:
	var b64: String = Marshalls.raw_to_base64((RELAY_PS % OS.get_process_id()).to_utf16_buffer())
	var proc: Dictionary = OS.execute_with_pipe("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-EncodedCommand", b64])
	if proc.is_empty():
		return null
	_pid = int(proc.get("pid", 0))
	var io: FileAccess = proc["stdio"]
	if _send(io, 0, {"v": 1, "client_id": app_id}) and str(_recv(io, true).get("evt", "")) == "READY":
		return io
	_close()
	return null

func _close() -> void:
	if _pid > 0:
		OS.kill(_pid)
	_pid = 0

# Frame: opcode (int32 LE), length (int32 LE), UTF-8 JSON
func _send(f: FileAccess, op: int, data: Dictionary) -> bool:
	var body: PackedByteArray = JSON.stringify(data).to_utf8_buffer()
	var buf := PackedByteArray()
	buf.resize(8)
	buf.encode_s32(0, op)
	buf.encode_s32(4, body.size())
	buf.append_array(body)
	f.store_buffer(buf)
	f.flush()
	return f.get_error() == OK

func _recv(f: FileAccess, wait_forever: bool = false) -> Dictionary:
	var head: PackedByteArray = _read_exact(f, 8, wait_forever)
	if head.size() < 8:
		return {}
	var n: int = head.decode_s32(4)
	if n <= 0 or n > 65536:
		return {}
	var body: PackedByteArray = _read_exact(f, n, false)
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

# Reads from the relay don't block: collect the bytes as they come (gives up after 10 s, or when the
# relay is gone; the handshake waits as long as the relay is waiting for Discord)
func _read_exact(f: FileAccess, n: int, wait_forever: bool) -> PackedByteArray:
	var out := PackedByteArray()
	var end: int = Time.get_ticks_msec() + 10000
	while out.size() < n and not _stopping():
		var part: PackedByteArray = f.get_buffer(n - out.size())
		if part.is_empty():
			if _pid <= 0 or not OS.is_process_running(_pid) or (not wait_forever and Time.get_ticks_msec() > end):
				break
			OS.delay_msec(30)
		out.append_array(part)
	return out
