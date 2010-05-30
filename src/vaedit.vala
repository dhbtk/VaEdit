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
			Gtk.MenuItem file_menu_item = new Gtk.MenuItem.with_mnemonic("_File");
			menu_bar.append(file_menu_item);
			Gtk.Menu file_menu = new Gtk.Menu();
			file_menu_item.submenu = file_menu;
			
			Gtk.ImageMenuItem file_new = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_NEW,accelerators);
			file_menu.append(file_new);
			file_new.activate.connect(() => {open_file(null,null);});
			
			Gtk.ImageMenuItem file_open = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_OPEN,accelerators);
			file_menu.append(file_open);
			file_open.activate.connect(() => {
				Gtk.FileChooserDialog dialog = new Gtk.FileChooserDialog("Select file",main_window,Gtk.FileChooserAction.OPEN,Gtk.STOCK_OPEN,1,Gtk.STOCK_CANCEL,2,null);
				dialog.response.connect((id) => {
					if(id==2){dialog.destroy(); return;}
					print(dialog.get_filename()+"\n");
					string file;
					string path;
					string[] raw_path = dialog.get_filename().split("/");
					file = raw_path[raw_path.length-1];
					raw_path = raw_path[0:raw_path.length-1];
					path = string.joinv("/",raw_path)+"/";
					open_file(file,path);
					dialog.destroy();
				});
				dialog.run();
			});
			
			Gtk.ImageMenuItem file_save = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_SAVE,accelerators);
			file_menu.append(file_save);
			file_save.activate.connect(() => {
				foreach(File file in files) {
					if(files_notebook.page_num(file.scroll) == files_notebook.page) {
						print("\""+file.filepath+"\"\n");
						bool dontdoit = false;
						if(file.filepath.strip().length == 0) {
							Gtk.FileChooserDialog dialog = new Gtk.FileChooserDialog("Choose a file name",main_window,Gtk.FileChooserAction.SAVE,Gtk.STOCK_SAVE,1,Gtk.STOCK_CANCEL,2,null);
							dialog.response.connect((id) => {
								if(id==2){dontdoit = true;dialog.destroy();return;}
								string filename;
								string path;
								string[] raw_path = dialog.get_filename().split("/");
								filename = raw_path[raw_path.length-1];
								raw_path = raw_path[0:raw_path.length-1];
								path = string.joinv("/",raw_path)+"/";
								file.filename = filename;
								file.filepath = path;
								file.label.set_text(filename);
								dialog.destroy();
							});
							dialog.run();
						}
						if(!dontdoit) {
							FileUtils.set_contents(file.filepath+file.filename,file.view.buffer.text);
							file.modified = false;
							update_title();
						}
						break;
					}
				}
			});
			
			Gtk.ImageMenuItem file_save_as = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_SAVE_AS,accelerators);
			file_menu.append(file_save_as);
			file_save_as.activate.connect(() => {
				foreach(File file in files) {
					if(files_notebook.page_num(file.scroll) == files_notebook.page) {
						print("\""+file.filepath+"\"\n");
						bool dontdoit = false;
						Gtk.FileChooserDialog dialog = new Gtk.FileChooserDialog("Choose a file name",main_window,Gtk.FileChooserAction.SAVE,Gtk.STOCK_SAVE,1,Gtk.STOCK_CANCEL,2,null);
						dialog.response.connect((id) => {
							if(id==2){dontdoit = true;dialog.destroy();return;}
							string filename;
							string path;
							string[] raw_path = dialog.get_filename().split("/");
							filename = raw_path[raw_path.length-1];
							raw_path = raw_path[0:raw_path.length-1];
							path = string.joinv("/",raw_path)+"/";
							file.filename = filename;
							file.filepath = path;
							file.label.set_text(filename);
							dialog.destroy();
						});
						dialog.run();
						if(!dontdoit) {
							FileUtils.set_contents(file.filepath+file.filename,file.view.buffer.text);
							file.modified = false;
							update_title();
						}
						break;
					}
				}
			});
			
			Gtk.ImageMenuItem file_close = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_CLOSE,accelerators);
			file_menu.append(file_close);
			file_close.activate.connect(() => {
				foreach(File file in files) {
					if(files_notebook.page_num(file.scroll) == files_notebook.page) {
						if(file.modified) {
							Gtk.MessageDialog dialog = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.WARNING,Gtk.ButtonsType.YES_NO,"The file has unsaved changes, close anyway?");
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
			
			Gtk.ImageMenuItem file_exit = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_QUIT,accelerators);
			file_menu.append(file_exit);
			file_exit.activate.connect(() => {
				if(!quit_app()) {
					Gtk.main_quit();
				}
			});
			
			files_notebook = new Gtk.Notebook();
			files_notebook.switch_page.connect((page,num) => {update_title(file_at_page((int)num));});
			main_vbox.pack_start(files_notebook,true,true,0);
			
			main_window.show_all();
			
			files = new LinkedList<File>();
			config_manager = new ConfigManager();
			config = config_manager.config;
		}
		
		private bool open_file(string? name = null,string? path = null) {
			foreach(File file in files) {
				if(file.filename == name && file.filepath == path) { // Case-sensitive!
					return false; // File is already open
				}
			}
			if(name == null) {
				name = "untitled";
			}
			if(path == null) {
				path = "";
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
			foreach(File file in files) {
				if(files_notebook.page_num(file.scroll) == files_notebook.page) {
					return file;
				}
			}
			return null;
		}
		
		public void update_title(owned File? file = null) {
			if(file == null) {
				file = current_file();
			}
			if(file == null) {
				main_window.title = "VaEdit";
			} else {
				main_window.title = (file.modified ? "* " : "")+file.filename+" - "+file.filepath+" - VaEdit";
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
		
		private bool quit_app() {
			foreach(File file in files) {
				if(file.modified) {
					Gtk.MessageDialog dialog = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.WARNING,Gtk.ButtonsType.YES_NO,"Some files have unsaved changes, quit anyway?");
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
					break;
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
				file.view.modify_font(Pango.FontDescription.from_string(config["core"]["font"]));
				
				Gtk.SourceStyleScheme scheme;
				
				Gtk.SourceStyleSchemeManager.get_default().prepend_search_path("/usr/share/gtksourceview-2.0/styles");
				foreach(string id in Gtk.SourceStyleSchemeManager.get_default().scheme_ids) {
					print(id+"\n");
					print(Gtk.SourceStyleSchemeManager.get_default().get_scheme(id).name+"\n");
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
				buffer.text = file;
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
