using Gee;
namespace VaEdit {
	GUI gui;
	public class GUI {
		public Gtk.Window main_window;
		public Gtk.MenuBar menu_bar;
		public Gtk.Notebook files_notebook;
		public LinkedList<File> files;
		public ConfigManager config_manager;
		public HashMap<string,HashMap<string,string>> config;
		private Gtk.AccelGroup accelerators;
		private SList<Gtk.RadioMenuItem> language_radios = new SList<Gtk.RadioMenuItem>();
		private LinkedList<Gtk.SourceLanguage> languages = new LinkedList<Gtk.SourceLanguage>();
		public Gtk.RadioMenuItem none_button;
		
		public GUI() {
			// Setting up the GUI
			accelerators = new Gtk.AccelGroup();
			main_window = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
			main_window.title = "VaEdit";
			main_window.set_size_request(640,320);
			main_window.delete_event.connect(quit_app);
			main_window.destroy.connect(Gtk.main_quit);
			main_window.add_accel_group(accelerators);
			
			Gtk.VBox main_vbox = new Gtk.VBox(false,0);
			main_window.add(main_vbox);
			
			menu_bar = new Gtk.MenuBar();
			main_vbox.pack_start(menu_bar,false,true,0);
			
			// Menus etc
			
			// File menu
			Gtk.MenuItem file_menu_item = new Gtk.MenuItem.with_mnemonic(_("_File"));
			menu_bar.append(file_menu_item);
			Gtk.Menu file_menu = new Gtk.Menu();
			file_menu_item.submenu = file_menu;
			
			// New file
			Gtk.ImageMenuItem file_new = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_NEW,accelerators);
			file_menu.append(file_new);
			file_new.activate.connect(() => {open_file(null,null);});
			
			// Open file
			Gtk.ImageMenuItem file_open = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_OPEN,accelerators);
			file_menu.append(file_open);
			file_open.activate.connect(() => {
				Gtk.FileChooserDialog dialog = new Gtk.FileChooserDialog(_("Select file"),main_window,Gtk.FileChooserAction.OPEN,Gtk.STOCK_OPEN,1,Gtk.STOCK_CANCEL,2,null);
				dialog.set_current_folder((current_file() != null && current_file().filepath != "" ? current_file().filepath : Environment.get_home_dir()));
				dialog.file_activated.connect(() => {
					open_file_from_path(dialog.get_filename().split("/"));
					dialog.destroy();
				});
				dialog.response.connect((id) => {
					if(id==2 || dialog.get_filename() == null){dialog.destroy(); return;}
					open_file_from_path(dialog.get_filename().split("/"));
					dialog.destroy();
				});
				dialog.run();
			});
			
			// Save file
			Gtk.ImageMenuItem file_save = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_SAVE,accelerators);
			file_menu.append(file_save);
			file_save.activate.connect(() => {
				foreach(File file in files) {
					if(files_notebook.page_num(file.scroll) == files_notebook.page) {
						print("\""+file.filepath+"\"\n");
						if(file.filepath.strip().length == 0) {
							Gtk.FileChooserDialog dialog = new Gtk.FileChooserDialog(_("Choose a file name"),main_window,Gtk.FileChooserAction.SAVE,Gtk.STOCK_SAVE,1,Gtk.STOCK_CANCEL,2,null);
							dialog.set_current_folder((file.filepath == "" ? Environment.get_home_dir() : file.filepath));
							dialog.file_activated.connect(() => {
								Gtk.MessageDialog confirm_dialog = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.WARNING,Gtk.ButtonsType.YES_NO,_("That file alreadly exists. Overwrite?"));
								confirm_dialog.response.connect((id) => {
									confirm_dialog.destroy();
									if(id == Gtk.ResponseType.YES && dialog.get_filename() != null) {
										save_file(file,dialog.get_filename().split("/"));
									}
									dialog.destroy();
								});
								confirm_dialog.run();
							});
							dialog.response.connect((id) => {
								if(id==2){dialog.destroy(); return;}
								save_file(file,dialog.get_filename().split("/"));
								dialog.destroy();
							});
							dialog.run();
						} else {
							save_file(file);
						}
						break;
					}
				}
			});
			
			// Save as...
			Gtk.ImageMenuItem file_save_as = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_SAVE_AS,accelerators);
			file_menu.append(file_save_as);
			file_save_as.activate.connect(() => {
				foreach(File file in files) {
					if(files_notebook.page_num(file.scroll) == files_notebook.page) {
						print("\""+file.filepath+"\"\n");
						Gtk.FileChooserDialog dialog = new Gtk.FileChooserDialog(_("Choose a file name"),main_window,Gtk.FileChooserAction.SAVE,Gtk.STOCK_SAVE,1,Gtk.STOCK_CANCEL,2,null);
						dialog.set_current_folder((file.filepath == "" ? Environment.get_home_dir() : file.filepath));
						dialog.file_activated.connect(() => {
							Gtk.MessageDialog confirm_dialog = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.WARNING,Gtk.ButtonsType.YES_NO,_("That file alreadly exists. Overwrite?"));
							confirm_dialog.response.connect((id) => {
								confirm_dialog.destroy();
								if(id == Gtk.ResponseType.YES) {
									save_file(file,dialog.get_filename().split("/"));
								}
								dialog.destroy();
							});
							confirm_dialog.run();
						});
						dialog.response.connect((id) => {
							if(id==2){dialog.destroy(); return;}
							save_file(file,dialog.get_filename().split("/"));
							dialog.destroy();
						});
						dialog.run();
						break;
					}
				}
			});
			
			// Close file
			Gtk.ImageMenuItem file_close = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_CLOSE,accelerators);
			file_menu.append(file_close);
			file_close.activate.connect(() => {
				foreach(File file in files) {
					if(files_notebook.page_num(file.scroll) == files_notebook.page) {
						if(file.modified) {
							Gtk.MessageDialog dialog = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.WARNING,Gtk.ButtonsType.YES_NO,_("The file has unsaved changes, close anyway?"));
							dialog.response.connect((response) => {
								dialog.destroy();
								if(response == Gtk.ResponseType.YES) {
									close_file(file);
								} else {
									return; // Do nothing
								}
							});
							dialog.run();
						} else {
							close_file(file);
						}
						break;
					}
				}});
			
			// Quit editor
			Gtk.ImageMenuItem file_exit = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_QUIT,accelerators);
			file_menu.append(file_exit);
			file_exit.activate.connect(() => {
				if(!quit_app()) {
					Gtk.main_quit();
				}
			});
			
			// Edit
			Gtk.MenuItem edit_menu_item = new Gtk.MenuItem.with_mnemonic("_Edit");
			menu_bar.append(edit_menu_item);
			Gtk.Menu edit_menu = new Gtk.Menu();
			edit_menu_item.submenu = edit_menu;
			
			// Undo
			Gtk.ImageMenuItem edit_undo = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_UNDO,accelerators);
			edit_menu.append(edit_undo);
			edit_undo.activate.connect(() => {
				if(current_file() != null) {
					current_file().buffer.undo();
				}
			});
			edit_undo.add_accelerator("activate",accelerators,Gdk.keyval_from_name("Z"),Gdk.ModifierType.CONTROL_MASK,Gtk.AccelFlags.VISIBLE);
			
			// Redo
			Gtk.ImageMenuItem edit_redo = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_REDO,accelerators);
			edit_menu.append(edit_redo);
			edit_redo.activate.connect(() => {
				if(current_file() != null) {
					current_file().buffer.redo();
				}
			});
			edit_redo.add_accelerator("activate",accelerators,Gdk.keyval_from_name("Z"),Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK,Gtk.AccelFlags.VISIBLE);
			
			// Preferences
			Gtk.ImageMenuItem edit_preferences = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_PREFERENCES,accelerators);
			edit_menu.append(edit_preferences);
			edit_preferences.activate.connect(() => {
				Gtk.Dialog dialog = new Gtk.Dialog.with_buttons(_("Preferences"),main_window,Gtk.DialogFlags.MODAL,Gtk.STOCK_SAVE,Gtk.ResponseType.ACCEPT,Gtk.STOCK_CANCEL,Gtk.ResponseType.REJECT,null);
				Gtk.CheckButton auto_indent = new Gtk.CheckButton.with_label(_("Auto-indent"));
				dialog.vbox.pack_start(auto_indent,false,true,4);
				
				Gtk.HBox idwidth_hbox = new Gtk.HBox(false,0);
				Gtk.SpinButton indentation_width = new Gtk.SpinButton.with_range(0,100,1);
				idwidth_hbox.pack_start(indentation_width,false,true,0);
				Gtk.Label idwidth_label = new Gtk.Label("Indentation width");
				idwidth_hbox.pack_start(idwidth_label,false,true,0);
				dialog.vbox.pack_start(idwidth_hbox,false,true,4);
				
				Gtk.CheckButton tabs_over_spaces = new Gtk.CheckButton.with_label(_("Insert tabs instead of spaces"));
				dialog.vbox.pack_start(tabs_over_spaces,false,true,4);
				
				Gtk.CheckButton show_line_numbers = new Gtk.CheckButton.with_label(_("Show line numbers"));
				dialog.vbox.pack_start(show_line_numbers,false,true,4);
				
				Gtk.CheckButton highlight_current_line = new Gtk.CheckButton.with_label(_("Highlight current line"));
				dialog.vbox.pack_start(highlight_current_line,false,true,4);
				
				Gtk.CheckButton highlight_matching_brackets = new Gtk.CheckButton.with_label(_("Highlight matching brackets"));
				dialog.vbox.pack_start(highlight_matching_brackets,false,true,4);
				
				Gtk.CheckButton show_right_margin = new Gtk.CheckButton.with_label(_("Show right margin"));
				dialog.vbox.pack_start(show_right_margin,false,true,4);
				
				Gtk.HBox rmar_hbox = new Gtk.HBox(false,0);
				Gtk.SpinButton right_margin_column = new Gtk.SpinButton.with_range(0,200,1);
				rmar_hbox.pack_start(right_margin_column,false,true,0);
				Gtk.Label rmar_label = new Gtk.Label(_("Right margin column"));
				rmar_hbox.pack_start(rmar_label,false,true,0);
				dialog.vbox.pack_start(rmar_hbox,false,true,4);
				
				Gtk.Label font_label = new Gtk.Label(_("Font:"));
				dialog.vbox.pack_start(font_label,false,true,4);
				Gtk.FontButton font = new Gtk.FontButton.with_font(config["core"]["font"]);
				dialog.vbox.pack_start(font,false,true,4);
				
				Gtk.Label scheme_label = new Gtk.Label(_("Color scheme:"));
				dialog.vbox.pack_start(scheme_label,false,true,4);
				Gtk.ComboBox scheme_box = new Gtk.ComboBox.text();
				dialog.vbox.pack_start(scheme_box,false,true,4);
				
				SList<string> names_list = new SList<string>();
				foreach(string id in Gtk.SourceStyleSchemeManager.get_default().get_scheme_ids()) {
					names_list.append(Gtk.SourceStyleSchemeManager.get_default().get_scheme(id).get_name());
					scheme_box.append_text(Gtk.SourceStyleSchemeManager.get_default().get_scheme(id).get_name());
				}
				
				dialog.show_all();
				
				// Feeding data
				auto_indent.active                 = config["core"]["auto_indent"] == "true";
				indentation_width.value            = config["core"]["indent_width"].to_int();
				tabs_over_spaces.active            = config["core"]["indent_with_tabs"] == "true";
				show_line_numbers.active           = config["core"]["show_line_numbers"] == "true";
				highlight_current_line.active      = config["core"]["highlight_current_line"] == "true";
				highlight_matching_brackets.active = config["core"]["highlight_matching_brackets"] == "true";
				show_right_margin.active           = config["core"]["show_right_margin"] == "true";
				right_margin_column.value          = config["core"]["right_margin_position"].to_int();
				int i = 0;
				foreach(string name in names_list) {
					if(name == config["core"]["color_scheme"]) {
						scheme_box.active = i;
						break;
					}
					i++;
				}
				
				dialog.response.connect((id) => {
					dialog.destroy();
					if(id == Gtk.ResponseType.ACCEPT) {
						config["core"]["auto_indent"]       = auto_indent.active ? "true" : "false";
						config["core"]["indent_width"]      = indentation_width.value.to_string();
						config["core"]["indent_with_tabs"]  = tabs_over_spaces.active ? "true" : "false";
						config["core"]["show_line_numbers"] = show_line_numbers.active ? "true" : "false";
						config["core"]["highlight_current_line"] = highlight_current_line.active ? "true" : "false";
						config["core"]["highlight_matching_brackets"] = highlight_matching_brackets.active ? "true" : "false";
						config["core"]["show_right_margin"] = show_right_margin.active ? "true" : "false";
						config["core"]["font"] = font.font_name;
						config["core"]["color_scheme"] = names_list.nth_data(scheme_box.active);
						config_manager.save_data();
						apply_settings();
					} else {
						return;
					}
				});
				dialog.run();
			});
			edit_preferences.add_accelerator("activate",accelerators,Gdk.keyval_from_name("P"),Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.MOD1_MASK,Gtk.AccelFlags.VISIBLE);
			
			// View menu
			Gtk.MenuItem view_menu_item = new Gtk.MenuItem.with_mnemonic(_("_View"));
			menu_bar.append(view_menu_item);
			Gtk.Menu view_menu = new Gtk.Menu();
			view_menu_item.submenu = view_menu;
			
			// Languages submenu
			Gtk.MenuItem view_languages_item = new Gtk.MenuItem.with_mnemonic(_("_Languages"));
			Gtk.Menu view_languages = new Gtk.Menu();
			view_languages_item.submenu = view_languages;
			view_menu.append(view_languages_item);
			
			// Dynamically-generated radio buttons for languages
			foreach(string id in Gtk.SourceLanguageManager.get_default().get_language_ids()) {
				languages.add(Gtk.SourceLanguageManager.get_default().get_language(id));
			}
			languages.sort((langa,langb) => {
				if((langa as Gtk.SourceLanguage).name > (langb as Gtk.SourceLanguage).name) {
					return 1;
				} else if((langa as Gtk.SourceLanguage).name == (langb as Gtk.SourceLanguage).name) {
					return 0;
				} else {
					return -1;
				}
			});
			// "none" button
			none_button = new Gtk.RadioMenuItem.with_mnemonic(language_radios,_("_None"));
			//language_radios = none_button.get_group();
			view_languages.append(none_button);
			none_button.toggled.connect(() => {
				if(none_button.active && current_file() != null) {
					current_file().buffer.language = null;
				}
			});
			foreach(Gtk.SourceLanguage language in languages) {
				Gtk.RadioMenuItem lang = new Gtk.RadioMenuItem.with_label_from_widget(none_button,language.name);
				language_radios.append(lang);
				lang.active = false;
				lang.toggled.connect(() => {
					if(lang.active) {
						foreach(Gtk.SourceLanguage _language in languages) {
							if(lang.label == _language.name && current_file() != null) {
								current_file().buffer.language = _language;
								break;
							}
						}
					}
				});
				view_languages.append(lang);
			}
			
			// Previous file
			Gtk.MenuItem view_prev_file = new Gtk.MenuItem.with_mnemonic(_("_Previous file"));
			view_prev_file.activate.connect(files_notebook.prev_page);
			view_prev_file.add_accelerator("activate",accelerators,Gdk.keyval_from_name("pagedown"),Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.MOD1_MASK,Gtk.AccelFlags.VISIBLE);
			
			// Next file
			Gtk.MenuItem view_next_file = new Gtk.MenuItem.with_mnemonic(_("_Next file"));
			view_next_file.activate.connect(files_notebook.next_page);
			view_prev_file.add_accelerator("activate",accelerators,Gdk.keyval_from_name("pageup"),Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.MOD1_MASK,Gtk.AccelFlags.VISIBLE);
			
			// Notebook holding the files
			files_notebook = new Gtk.Notebook();
			files_notebook.switch_page.connect((page,num) => {update_title(file_at_page((int)num));});
			main_vbox.pack_start(files_notebook,true,true,0);
			
			main_window.show_all();
			
			files = new LinkedList<File>();
			config_manager = new ConfigManager();
			config = config_manager.config;
			
			// Default file
			open_file();
		}
		
		private bool open_file(string? name = null,string? path = null) {
			foreach(File file in files) {
				if(file.filename == name && file.filepath == path) { // Case-sensitive!
					return false; // File is already open
				}
			}
			if(name == null) {
				name = _("untitled");
			}
			if(path == null) {
				path = "";
			}
			
			if(files.size == 1 && files[0].filename == _("untitled") && files[0].filepath == "" && files[0].modified == false) {
				close_file(files[0]);
			}
			
			File file = new File(name,path);
			files.add(file);
			files_notebook.append_page(file.scroll,file.label);
			files_notebook.show_all();
			files_notebook.page = files_notebook.page_num(file.scroll);
			apply_settings();
			
			return true;
		}
		
		public File? current_file() {
			return file_at_page(files_notebook.page);
		}
		
		public void update_title(owned File? file = null) {
			if(file == null) {
				file = current_file();
			}
			if(file == null) {
				main_window.title = "VaEdit";
				none_button.active = true;
			} else {
				main_window.title = (file.modified ? "* " : "")+file.filename+" - "+file.filepath+" - VaEdit";
				/*if(file.buffer.language == null) {
					none_button.active = true;
				} else {
					print(file.buffer.language.name+"\n");
					foreach(Gtk.RadioMenuItem button in language_radios) {
						if(button.label == file.buffer.language.name) {
							button.active = true;
							break;
						}
					}
				}*/
			}
		}
		
		private File? file_at_page(int page) {
			foreach(File file in files) {
				if(files_notebook.page_num(file.scroll) == page) {
					return file;
				}
			}
			return null;
		}
		
		private void close_file(File file) {
			files_notebook.remove_page(files_notebook.page_num(file.scroll));
			files.remove(file);
			update_title();
		}
		
		private void open_file_from_path(string[] _raw_path) {
			string file = _raw_path[_raw_path.length-1];
			string[] raw_path = _raw_path[0:_raw_path.length-1];
			string path = string.joinv("/",raw_path)+"/";
			print(path+"\n");
			print(file+"\n");
			open_file(file,path);
		}
		
		private void save_file(File file,string[]? _raw_path = null) {
			if(_raw_path != null) {
				string filename = _raw_path[_raw_path.length-1];
				string[] raw_path = _raw_path[0:_raw_path.length-1];
				string path = string.joinv("/",raw_path)+"/";
				file.filename = filename;
				file.filepath = path;
				file.label.set_text(filename);
			}
			FileUtils.set_contents(file.filepath+file.filename,file.view.buffer.text);
			file.modified = false;
			update_title();
		}
		
		private bool quit_app() {
			foreach(File file in files) {
				if(file.modified) {
					Gtk.MessageDialog dialog = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.WARNING,Gtk.ButtonsType.YES_NO,_("Some files have unsaved changes, quit anyway?"));
					bool quit = false;
					dialog.response.connect((id) => {
						dialog.destroy();
						if(id == Gtk.ResponseType.YES) {
							quit = false;
						} else {
							quit = true;
						}
					});
					dialog.run();
					return quit;
				}
			}
			return false;
		}
		
		private void apply_settings() {
			foreach(File file in files) {
				print("Applying\n");
				file.view.auto_indent = config["core"]["auto_indent"] == "true";
				file.view.highlight_current_line = config["core"]["highlight_current_line"] == "true";
				file.view.indent_on_tab = true;
				file.view.insert_spaces_instead_of_tabs = config["core"]["indent_with_tabs"] != "true";
				//file.view.indent_width = config["core"]["indent_width"].to_int();
				file.view.tab_width = config["core"]["indent_width"].to_int();
				file.view.show_line_numbers = config["core"]["show_line_numbers"] == "true";
				file.view.show_right_margin = config["core"]["show_right_margin"] == "true";
				file.view.right_margin_position = config["core"]["right_margin_position"].to_int();
				file.buffer.highlight_matching_brackets = config["core"]["highlight_matching_brackets"] == "true";
				file.view.modify_font(Pango.FontDescription.from_string(config["core"]["font"]));
				
				Gtk.SourceStyleScheme scheme;
				
				Gtk.SourceStyleSchemeManager.get_default().prepend_search_path("/usr/share/gtksourceview-2.0/styles");
				foreach(string id in Gtk.SourceStyleSchemeManager.get_default().get_scheme_ids()) {
					if(Gtk.SourceStyleSchemeManager.get_default().get_scheme(id).name == config["core"]["color_scheme"]) {
						scheme = Gtk.SourceStyleSchemeManager.get_default().get_scheme(id);
						file.buffer.style_scheme = scheme;
						break;
					}
				}
			}
		}
	}
	
	public class File {
		public string filename;
		public string filepath;
		public Gtk.Label label;
		public Gtk.SourceView view;
		public Gtk.SourceBuffer buffer;
		public Gtk.ScrolledWindow scroll;
		public bool modified = false;
		
		public File(string filename,string filepath) throws Error {
			this.filename = filename;
			this.filepath = filepath;
			
			label  = new Gtk.Label(filename);
			buffer = new Gtk.SourceBuffer(new Gtk.TextTagTable());
			view   = new Gtk.SourceView.with_buffer(buffer);
			scroll = new Gtk.ScrolledWindow(null,null);
			scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			scroll.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			scroll.add(view);
			
			if(filepath.length > 0) {
				string file;
				bool result_uncertain;
				FileUtils.get_contents(filepath+filename,out file);
				string mimetype = g_content_type_guess(filepath+filename,(uchar[])file.to_utf8(),out result_uncertain);
				buffer.language = Gtk.SourceLanguageManager.get_default().guess_language(filepath+filename,(result_uncertain ? null : mimetype));
				buffer.begin_not_undoable_action();
				buffer.text = file;
				buffer.end_not_undoable_action();
			}
			buffer.changed.connect(() => {modified = true;gui.update_title();});
		}
	}
	
	void main(string[] args) {
		Gtk.init(ref args);
		gui = new GUI();
		
		Gtk.main();
	}
}
