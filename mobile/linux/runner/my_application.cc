#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  GtkStatusIcon* tray;
  GtkWidget* tray_menu;
  FlMethodChannel* desktop_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// the tray keeps the app running with the window closed, so messages keep
// arriving. gtk's status icon is the one tray every x11 desktop shows; on a
// desktop without a tray, closing the window ends the app as before
G_GNUC_BEGIN_IGNORE_DEPRECATIONS

static void show_window(MyApplication* self) {
  if (self->window == nullptr) return;
  gtk_widget_show(GTK_WIDGET(self->window));
  gtk_window_present(self->window);
}

static gboolean tray_shown(MyApplication* self) {
  return self->tray != nullptr && gtk_status_icon_is_embedded(self->tray);
}

static void tray_open_cb(GtkMenuItem*, gpointer user_data) {
  show_window(MY_APPLICATION(user_data));
}

static void tray_quit_cb(GtkMenuItem*, gpointer user_data) {
  g_application_quit(G_APPLICATION(user_data));
}

static void tray_activate_cb(GtkStatusIcon*, gpointer user_data) {
  show_window(MY_APPLICATION(user_data));
}

static void tray_popup_cb(GtkStatusIcon* icon, guint button, guint time,
                          gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  gtk_menu_popup(GTK_MENU(self->tray_menu), nullptr, nullptr,
                 gtk_status_icon_position_menu, icon, button, time);
}

static gchar* icon_path() {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe == nullptr) return nullptr;
  g_autofree gchar* dir = g_path_get_dirname(exe);
  return g_build_filename(dir, "data", "kryfo.png", nullptr);
}

// dart sends the menu's words in the app's language once it knows them
static void make_tray(MyApplication* self, const gchar* open,
                      const gchar* quit, const gchar* tip) {
  if (self->tray_menu != nullptr) gtk_widget_destroy(self->tray_menu);
  self->tray_menu = gtk_menu_new();
  GtkWidget* open_item = gtk_menu_item_new_with_label(open);
  GtkWidget* quit_item = gtk_menu_item_new_with_label(quit);
  g_signal_connect(open_item, "activate", G_CALLBACK(tray_open_cb), self);
  g_signal_connect(quit_item, "activate", G_CALLBACK(tray_quit_cb), self);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), open_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), quit_item);
  gtk_widget_show_all(self->tray_menu);
  if (self->tray == nullptr) {
    g_autofree gchar* path = icon_path();
    self->tray = path != nullptr && g_file_test(path, G_FILE_TEST_EXISTS)
                     ? gtk_status_icon_new_from_file(path)
                     : gtk_status_icon_new_from_icon_name(APPLICATION_ID);
    g_signal_connect(self->tray, "activate", G_CALLBACK(tray_activate_cb),
                     self);
    g_signal_connect(self->tray, "popup-menu", G_CALLBACK(tray_popup_cb),
                     self);
  }
  gtk_status_icon_set_tooltip_text(self->tray, tip);
  gtk_status_icon_set_title(self->tray, "Kryfo");
}

G_GNUC_END_IGNORE_DEPRECATIONS

static const gchar* map_string(FlValue* args, const gchar* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return "";
  }
  FlValue* v = fl_value_lookup_string(args, key);
  if (v == nullptr || fl_value_get_type(v) != FL_VALUE_TYPE_STRING) return "";
  return fl_value_get_string(v);
}

static void desktop_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                            gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(call), "tray") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    make_tray(self, map_string(args, "open"), map_string(args, "quit"),
              map_string(args, "tip"));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

// with a tray the window only hides, and the app goes on receiving
static gboolean delete_cb(GtkWidget* widget, GdkEvent*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (!tray_shown(self)) return FALSE;
  gtk_widget_hide(widget);
  return TRUE;
}

static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // a second start brings the running one forward: two processes on one
  // folder would fight over its database and its tor
  if (self->window != nullptr) {
    show_window(self);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_autofree gchar* icon = icon_path();
  if (icon != nullptr) gtk_window_set_icon_from_file(window, icon, nullptr);
  g_signal_connect(window, "delete-event", G_CALLBACK(delete_cb), self);

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Kryfo");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Kryfo");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->desktop_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "kryfo/desktop", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->desktop_channel,
                                            desktop_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->desktop_channel);
  g_clear_object(&self->tray);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_DEFAULT_FLAGS, nullptr));
}
