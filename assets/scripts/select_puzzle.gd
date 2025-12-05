extends Control

# this menu is used to select which puzzle the player wants to play

# these are variables for changing PageIndicator which is used
# to display the current page you are on
# ex:
#	PageIndicator will display:
#	1 out of 2
#	if you are on the first page out of
#	two pages total

var page_num = 1
# total_pages gets calculated in ready and is based off the amount
# of images in the image list
var total_pages # gets calculated in ready, is based off the amount of images
var page_string = "%d out of %d"
@onready var pageind = $PageIndicator # actual reference for PageIndicator
# buttons reference:
@onready var go_back_menu = $GoBackToMenu
@onready var left_button = $"HBoxContainer/left button"
@onready var right_button = $"HBoxContainer/right button"
@onready var size_label = $Panel/VBoxContainer/Thumbnail/size_label
@onready var hbox = $"HBoxContainer"
@onready var panel = $"Panel"
@onready var thumbnail = $Panel/VBoxContainer/Thumbnail
@onready var start_puzzle_button = $Panel/VBoxContainer/Start_Puzzle

# grid reference:
#have an array of images to pull from that will correspond to an integer returned by the buttons
#for each page take the integer and add a multiple of 9
@onready var grid = $"HBoxContainer/GridContainer"

var list = []

var local_puzzle_list = []
var puzzle_variants := []

func _build_puzzle_variants(puzzles: Array) -> Array:
	var variants: Array = []
	for puzzle in puzzles:
		if !(puzzle is Dictionary):
			continue
		var sizes: Array = puzzle.get("available_sizes", [10, 100, 1000])
		for size in sizes:
			var entry: Dictionary = puzzle.duplicate(true)
			entry["size"] = size
			variants.append(entry)
	return variants



# Called when the node enters the scene tree for the first time.
func _ready():
        # this code will iterate through the children of the grid which are buttons
        # and will link them so that they all carry out the same function
        # that function being button_pressed
        print("SELECT_PUZZLE")
        await PuzzleVar.refresh_puzzle_manifest()
        # populate local_puzzle_list with puzzles and size
        local_puzzle_list = PuzzleVar.get_avail_puzzles()
        puzzle_variants = _build_puzzle_variants(local_puzzle_list)
        print(local_puzzle_list)
        for i in grid.get_children():
                var button := i as BaseButton
                if is_instance_valid(button):
                        button.text = "" # set all buttons to have no text for formatting
                        # actual code connecting the button_pressed function to
                        # the buttons in the grid
                        button.pressed.connect(button_pressed.bind(button))
        #
        # this code gets the number of total pages
        var num_buttons = grid.get_child_count()
	var imgsize = float(puzzle_variants.size())
	var nb = float(num_buttons)
	total_pages = max(1, ceil(imgsize/nb)) # round up always to get total_pages
	# disable the buttons logic that controls switching pages depending on
	# how many pages there are
	left_button.disabled = true 
	if total_pages == 1:
		right_button.disabled = true
	# the await is required so that the pages have time to load in
	await get_tree().process_frame
	# populates the buttons in the grid with actual images so that you can
	# preview which puzzle you want to select
	self.populate_grid_2()

		
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# this code updates the display so that you know which page you are on
	pageind.text = page_string %[page_num,total_pages]

func _on_left_button_pressed():
	$AudioStreamPlayer.play()
	
	# decrements the current page you are on
	if page_num > 1:
		page_num -= 1
	
	# disables left button if you switch to page 1 and enables the right button
	if page_num == 1:
		left_button.disabled = true
		right_button.disabled = false
	
	# repopulates the grid with a new selection of images
	self.populate_grid_2()

func _on_right_button_pressed():
	$AudioStreamPlayer.play()
	
	# adds 1 to the current page you are on
	if page_num < total_pages:
		page_num += 1
	
	# if reach the last page, disables the right button and enables the left button
	if page_num == total_pages:
		right_button.disabled = true
		left_button.disabled = false
	
	# if it is some page in between 1 and the total number of pages
	# then have both buttons be enabled
	else:
		right_button.disabled = false
		left_button.disabled = false
	
	# repopulates the grid with a new selection of images
	self.populate_grid_2()

# this function selects the image that is previewed on the button for the puzzle
func button_pressed(button):
	#need to take val into account
	#do stuff to pick image

	#$AudioStreamPlayer.play() #this doesn't currently work because it switches scenes too quickly
	var chosen = button.get_meta("puzzle_index", -1)
	if chosen == -1:
		# fall back to original math when metadata is missing
		var index = (page_num-1) * grid.get_child_count()
		var button_name = String(button.name)
		chosen = index + int(button_name[-1])

	if chosen < 0 or chosen >= puzzle_variants.size():
		return

	var selection: Dictionary = puzzle_variants[chosen].duplicate(true)
	PuzzleVar.choice = selection

	# Show Continue panel
	hbox.hide()
	pageind.hide()
	var thumb_path = selection.get("thumbnail_storage_path", selection.get("file_path", ""))
	thumbnail.texture = load(thumb_path)
	size_label.text = str(selection.get("size", ""))
	panel.show()


func populate_grid_2():
        var buttons = grid.get_children()
        var columns = grid.columns
        var base_index = (page_num - 1) * buttons.size()

        for i in range(buttons.size()):
                var global_index = base_index + i
                var button = buttons[i]
                var tex_node = button.get_child(0)
                if not is_instance_valid(button) or tex_node == null:
                        continue
                button.set_meta("puzzle_index", -1)
                if global_index >= puzzle_variants.size():
                        tex_node.texture = null
                        continue

                var puzzle_data: Dictionary = puzzle_variants[global_index]
                var thumb_path = puzzle_data.get("thumbnail_storage_path", "")
                var res = load(thumb_path)
                if res == null:
                        res = load(puzzle_data.get("file_path", ""))
                tex_node.texture = res
                tex_node.size = button.size
                button.set_meta("puzzle_index", global_index)

			
			
# this function is what populates the grid with images so that you can
# preview which image you want to select
func populate_grid():
	# function starts by calculating the index of the image to start with
	# when populating the grid with 9 images
	var index = (page_num-1) * grid.get_child_count()
	# iterates through each child (button) of the grid and sets the buttons
	# texture to the appropriate image
	
	for i in grid.get_children():
		var button := i as BaseButton
		if is_instance_valid(button):
			if index < PuzzleVar.images.size():
				var file_path = PuzzleVar.path+"/"+PuzzleVar.images[index]
				var res = load(file_path)
				print("file_path: ", file_path, " loaded")
				button.get_child(0).texture = res
				button.get_child(0).size = button.size
				if FireAuth.offlineMode == 0:
					print(GlobalProgress.progress_arr)
					#add_custom_label(button, GlobalProgress.progress_arr[index])
				else:
					add_custom_label(button, 0)
				
			else:
				button.get_child(0).texture = null
			# iterates the index to get the next image after the image is
			# loaded in
			index += 1
			
			
func add_custom_label(button, percentage):
	# Create a Panel (Colored Background)
	var new_panel = Panel.new()
	new_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Flat style
	new_panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	# Customize the Panel's appearance
	
	
	var stylebox = new_panel.get_theme_stylebox("panel").duplicate()
	stylebox.bg_color = Color(0, 0, 0, 0.7)# Black with 70% opacity
	new_panel.add_theme_stylebox_override("panel", stylebox)

	# Set panel size and anchors (positioning)
	new_panel.anchor_left = 0.0
	new_panel.anchor_right = 1.0
	# Keeps it at the bottom of the button
	new_panel.anchor_top = 0.8
	new_panel.anchor_bottom = 1.0

	# Create Label (Text)
	var label = Label.new()
	label.text = "Progress: " + str(percentage) + "% completed" # Customize text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# Adjust text size
	label.add_theme_font_size_override("font_size", 30)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Add Panel and Label to the Button
	# Add the background first
	button.add_child(panel)
	# Add the text label on top of the background
	button.add_child(label)

	# Ensure Label is inside the Panel
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.8
	label.anchor_bottom = 1.0


func _on_start_puzzle_pressed() -> void:
        start_puzzle_button.disabled = true
        var cached_choice := await PuzzleVar.cache_puzzle_choice(PuzzleVar.choice)
        PuzzleVar.choice = cached_choice
        get_tree().change_scene_to_file("res://assets/scenes/jigsaw_puzzle_1.tscn")


func _on_go_back_pressed() -> void:
	panel.hide()
	pageind.show()
	hbox.show()


func _on_go_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/scenes/new_menu.tscn")
