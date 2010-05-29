using Gee;
namespace VaEdit {
	public class GUI {
		public Gtk.Window main_window;
		public Gtk.MenuBar menu_bar;
		public Gtk.Notebook files_notebook;
		public HashSet<File> files;
		
		public GUI() {
			// Setting up the GUI
			main_window = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
			main_window.title = "VaEdit - Idle";
			main_window.set_size_request(640,320);
			
			main_window.show_all();
		}
	}
	
	public class File {
		public string filename;
		public string filepath;
		public Gtk.SourceView view;
	}
	
	void main(string[] args) {
		Gtk.init(ref args);
		GUI gui = new GUI();
		
		Gtk.main();
	}
}
