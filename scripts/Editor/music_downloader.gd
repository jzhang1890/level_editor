extends Node

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

func _ready() -> void:
	pass

# PUBLIC FUNCTIONS CALLED BY UI 

func fetch_ncs(song_id: String) -> void:
	if song_id != "":
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
		current_song_id = song_id
		status_updated.emit("Fetching Newgrounds link...", false)
		is_ng_fetching_html = true
		var url = "https://www.newgrounds.com/audio/listen/" + song_id
		ng_http_request.request(url)


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
			status_updated.emit("Failed to load track page!", true)
			is_fetching_html = false

	else:
		if is_primary_download and not is_instrumental_download and (result != HTTPRequest.RESULT_SUCCESS or response_code != 200):
			_start_fallback_download()
			return

		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			status_updated.emit("Download complete!", true)
			download_complete.emit(fallback_title, fallback_artist, current_song_id, body)
		else:
			status_updated.emit("Download failed! Code: " + str(response_code), true)

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
			var html_string = body.get_string_from_utf8()
			var found_url = false
			
			if "NgAudioPlayer.fromListenPage({" in html_string:
				var payload = html_string.get_slice("NgAudioPlayer.fromListenPage({", 1)
				
				if "'author': \"" in payload:
					ng_artist = payload.get_slice("'author': \"", 1).get_slice("\"", 0).xml_unescape()
				else:
					ng_artist = "Unknown"
					
				if "'title': \"" in payload:
					ng_title = payload.get_slice("'title': \"", 1).get_slice("\"", 0).xml_unescape()
				else:
					ng_title = "Unknown"
				
				if "'url': \"" in payload:
					var raw_url = payload.get_slice("'url': \"", 1).get_slice("\"", 0)
					ng_mp3_url = raw_url.replace("\\/", "/")
					found_url = true
			
			if found_url:
				status_updated.emit("Downloading Newgrounds MP3...", false)
				is_ng_fetching_html = false
				ng_http_request.timeout = 0
				ng_http_request.request(ng_mp3_url)
			else:
				status_updated.emit("Could not find MP3 file", false)
				is_ng_fetching_html = false
		else:
			status_updated.emit("Failed to load Newgrounds page", false)
			is_ng_fetching_html = false
		print(response_code)

	else:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			status_updated.emit("Download complete!", false)
			download_complete.emit(ng_title, ng_artist, current_song_id, body)
		else:
			status_updated.emit("Download failed! Code: " + str(response_code), false)
