extends Node

# Signals for when something happens
signal status_updated(message: String, is_ncs: bool)
signal download_complete(title: String, artist: String, song_id: String, audio_data: PackedByteArray)
signal ncs_options_available(regular_url: String, inst_url: String)

# Network Tracking Variables
var is_fetching_html: bool = false
var is_primary_download: bool = false
var fallback_mp3_url: String = ""
var fallback_title: String = ""
var fallback_artist: String = ""
var regular_download_url: String = ""
var instrumental_download_url: String = ""
var is_instrumental_download: bool = false

var is_ng_fetching_html: bool = false
var ng_mp3_url: String = ""
var ng_title: String = ""
var ng_artist: String = ""

var current_song_id: String = ""

@onready var ncs_http_request: HTTPRequest = $HTTPRequest
@onready var ng_http_request: HTTPRequest = $NG_HTTPRequest

var browser_headers: PackedStringArray = PackedStringArray([
	"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
	"Referer: https://www.newgrounds.com/"
])

func _ready() -> void:
	pass

# PUBLIC FUNCTIONS CALLED BY UI 

func fetch_ncs(song_id: String) -> void:
	if song_id != "":
		# Check for local file first
		var file_path = "user://songs/" + song_id + ".mp3"
		if FileAccess.file_exists(file_path):
			# Pull the real data and update the status text to "Complete"
			var meta = _get_song_metadata(song_id)
			status_updated.emit("Loaded song", true) 
			
			var file = FileAccess.open(file_path, FileAccess.READ)
			var audio_data = file.get_buffer(file.get_length())
			file.close()
			
			# Pass the real title and artist to the UI
			download_complete.emit(meta["title"], meta["artist"], song_id, audio_data)
			return
			
		current_song_id = song_id
		status_updated.emit("Fetching NCS link...", true)
		is_fetching_html = true
		regular_download_url = ""
		instrumental_download_url = ""
		var url = "https://ncs.io/" + song_id
		ncs_http_request.request(url)
		
func download_ncs_regular() -> void:
	if regular_download_url == "":
		return
	status_updated.emit("Downloading MP3...", true)
	is_fetching_html = false
	is_primary_download = true
	is_instrumental_download = false
	ncs_http_request.timeout = 10.0
	ncs_http_request.request(regular_download_url)

func download_ncs_instrumental() -> void:
	if instrumental_download_url == "":
		return
	status_updated.emit("Downloading Instrumental MP3...", true)
	is_fetching_html = false
	is_primary_download = false
	is_instrumental_download = true
	ncs_http_request.timeout = 0
	ncs_http_request.request(instrumental_download_url)

func fetch_newgrounds(song_id: String) -> void:
	if song_id != "":
		# Check for local file first
		var file_path = "user://songs/" + song_id + ".mp3"
		if FileAccess.file_exists(file_path):
			var meta = _get_song_metadata(song_id)
			status_updated.emit("Loaded song", false) 
			
			var file = FileAccess.open(file_path, FileAccess.READ)
			var audio_data = file.get_buffer(file.get_length())
			file.close()
			
			download_complete.emit(meta["title"], meta["artist"], song_id, audio_data)
			return
			
		current_song_id = song_id
		status_updated.emit("Downloading audio...", false)
		is_ng_fetching_html = true
		
		# Use RobTop's database instead of scraping Newgrounds HTML
		var url = "https://www.boomlings.com/database/getGJSongInfo.php"
		var post_data = "songID=" + song_id + "&secret=Wmfd2893gb7"
		
		# Add blank User-Agent
		var headers = [
			"Content-Type: application/x-www-form-urlencoded",
			"User-Agent: " 
		]
		
		ng_http_request.request(url, headers, HTTPClient.METHOD_POST, post_data)
		
# INTERNAL HTTP REQUEST HANDLERS

func _on_ncs_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_fetching_html:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var html_string = body.get_string_from_utf8()
			
			if "<title>" in html_string:
				var raw_title = html_string.get_slice("<title>", 1).get_slice("</title>", 0).xml_unescape().replace(" on NCS", "")
				var title_parts = raw_title.split(" by ")
				if title_parts.size() >= 2:
					fallback_title = title_parts[0].strip_edges()
					fallback_artist = title_parts[1].strip_edges()
			if "id=\"player\" data-url=\"" in html_string:
				fallback_mp3_url = html_string.get_slice("id=\"player\" data-url=\"", 1).get_slice("\"", 0)

			var href_chunks = html_string.split("href=\"/track/download/")
			for i in range(1, href_chunks.size()):
				var chunk = href_chunks[i]
				var href_path = chunk.get_slice("\"", 0).replace(" ", "%20")
				var full_link = "https://ncs.io/track/download/" + href_path
				
				if "data-version=\"Instrumental\"" in chunk or "/i%20" in href_path or "/i " in chunk:
					instrumental_download_url = full_link
				elif "data-version=\"Regular\"" in chunk or regular_download_url == "":
					regular_download_url = full_link

			if regular_download_url != "":
				ncs_options_available.emit(regular_download_url, instrumental_download_url)
				status_updated.emit("Select a song version:", true)
				is_fetching_html = false
			else:
				_start_fallback_download()
		else:
			status_updated.emit("Failed to load track page", true)
			is_fetching_html = false

	else:
		if is_primary_download and not is_instrumental_download and (result != HTTPRequest.RESULT_SUCCESS or response_code != 200):
			_start_fallback_download()
			return

		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			# Save the metadata to JSON file
			_save_song_metadata(current_song_id, fallback_title, fallback_artist)
			
			status_updated.emit("Download complete", true)
			download_complete.emit(fallback_title, fallback_artist, current_song_id, body)
		else:
			status_updated.emit("Download failed, Code: " + str(response_code), true)

func _start_fallback_download() -> void:
	if fallback_mp3_url != "":
		status_updated.emit("Downloading MP3...", true)
		is_fetching_html = false
		is_primary_download = false
		ncs_http_request.timeout = 0
		ncs_http_request.request(fallback_mp3_url)
	else:
		status_updated.emit("MP3 link not found!", true)
		is_fetching_html = false

func _on_ng_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_ng_fetching_html:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var data = body.get_string_from_utf8()
			
			# Boomlings returns "-1" or "-2" if the song isn't allowed 
			if data == "-1" or data == "-2" or data.is_empty():
				status_updated.emit("Song not allowed", false)
				is_ng_fetching_html = false
				return
				
			var parts = data.split("~|~")
			var found_url = false
			
			# Parse the Boomlings array format
			for i in range(0, parts.size() - 1, 2):
				var key = parts[i]
				var val = parts[i+1]
				
				if key == "2":
					ng_title = val.xml_unescape()
				elif key == "4":
					ng_artist = val.xml_unescape()
				elif key == "10":
					# Decode the percent-encoded URL back into standard https://
					ng_mp3_url = val.uri_decode()
					found_url = true
			
			if found_url:
				status_updated.emit("Downloading Newgrounds MP3...", false)
				is_ng_fetching_html = false
				ng_http_request.timeout = 0
				
				ng_http_request.request(ng_mp3_url, browser_headers)
			else:
				status_updated.emit("Could not find MP3 file", false)
				is_ng_fetching_html = false
		else:
			status_updated.emit("Failed to connect to servers", false)
			is_ng_fetching_html = false

	else:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			# Save song metadata to JSON file
			_save_song_metadata(current_song_id, ng_title, ng_artist)
			
			status_updated.emit("Download complete", false)
			download_complete.emit(ng_title, ng_artist, current_song_id, body)
		else:
			status_updated.emit("Download failed, Code: " + str(response_code), false)

const METADATA_PATH = "user://songs/metadata.json"

func _save_song_metadata(id: String, title: String, artist: String) -> void:
	var meta = {}
	
	# Load the existing address book if it exists
	if FileAccess.file_exists(METADATA_PATH):
		var read_file = FileAccess.open(METADATA_PATH, FileAccess.READ)
		var json = JSON.parse_string(read_file.get_as_text())
		read_file.close()
		if typeof(json) == TYPE_DICTIONARY:
			meta = json
			
	# Add the new song data
	meta[id] = {"title": title, "artist": artist}
	
	# Make sure the songs folder exists, then save the updated book
	if not DirAccess.dir_exists_absolute("user://songs"):
		DirAccess.make_dir_absolute("user://songs")
		
	var write_file = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(meta))
	write_file.close()

func _get_song_metadata(id: String) -> Dictionary:
	# Read the book and return the title and artist for the requested ID
	if FileAccess.file_exists(METADATA_PATH):
		var file = FileAccess.open(METADATA_PATH, FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(json) == TYPE_DICTIONARY and json.has(id):
			return json[id]
			
	# Fallback if the song isn't in the book
	return {"title": "Unknown Title", "artist": "Unknown Artist"}
