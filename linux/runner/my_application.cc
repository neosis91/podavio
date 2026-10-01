#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

#ifndef PODAVIO_VERSION
#define PODAVIO_VERSION ""
#endif
#ifndef PODAVIO_DESKTOP_VERSION
#define PODAVIO_DESKTOP_VERSION "1.0"
#endif

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar* resolve_podavio_icon_path();
static gchar* resolve_exe_path();
static void install_wayland_desktop_entry();
static void set_podavio_icon(GtkWindow* window);

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
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
    gtk_header_bar_set_title(header_bar, "Podavio");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Podavio");
  }

  gtk_window_set_default_size(window, 1280, 720);
  set_podavio_icon(window);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#F4F6FB");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as the binary name.
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

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  g_set_application_name("Podavio");
  g_autofree gchar* icon_path = resolve_podavio_icon_path();
  if (icon_path != nullptr) {
    g_autoptr(GError) error = nullptr;
    if (!gtk_window_set_default_icon_from_file(icon_path, &error)) {
      g_warning("Icône Podavio par défaut : %s", error->message);
    }
  }

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static gchar* resolve_exe_path() {
  return g_file_read_link("/proc/self/exe", nullptr);
}

static gchar* resolve_podavio_icon_path() {
  g_autofree gchar* exe_path = resolve_exe_path();
  if (exe_path == nullptr) return nullptr;
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);

  const gchar* candidates[] = {
      "data/podavio.png",
      "data/flutter_assets/assets/brand/icon.png",
      nullptr,
  };
  for (int i = 0; candidates[i] != nullptr; i++) {
    g_autofree gchar* path =
        g_build_filename(exe_dir, candidates[i], nullptr);
    if (g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
      return g_steal_pointer(&path);
    }
  }
  return nullptr;
}

// Wayland ignore gtk_window_set_icon* : l’icône vient du .desktop dont le
// nom = application-id (ici fr.podavio.podavio.desktop).
static void install_wayland_desktop_entry() {
  g_autofree gchar* exe_path = resolve_exe_path();
  g_autofree gchar* icon_src = resolve_podavio_icon_path();
  if (exe_path == nullptr || icon_src == nullptr) return;

  const gchar* home = g_get_home_dir();
  if (home == nullptr) return;

  const int sizes[] = {256, 128, 64, 48, 32, 24, 16};
  g_autoptr(GError) error = nullptr;
  g_autoptr(GdkPixbuf) source = gdk_pixbuf_new_from_file(icon_src, &error);
  if (source == nullptr) {
    g_warning("Icône Podavio illisible pour le thème : %s", error->message);
    return;
  }

  for (guint i = 0; i < G_N_ELEMENTS(sizes); i++) {
    g_autofree gchar* size_dir = g_strdup_printf("%dx%d", sizes[i], sizes[i]);
    g_autofree gchar* icon_dir = g_build_filename(
        home, ".local", "share", "icons", "hicolor", size_dir, "apps", nullptr);
    if (g_mkdir_with_parents(icon_dir, 0755) != 0) continue;

    g_autofree gchar* icon_dst = g_build_filename(
        icon_dir, APPLICATION_ID ".png", nullptr);
    g_autoptr(GdkPixbuf) scaled = gdk_pixbuf_scale_simple(
        source, sizes[i], sizes[i], GDK_INTERP_BILINEAR);
    if (scaled == nullptr) continue;
    g_autoptr(GError) save_error = nullptr;
    if (!gdk_pixbuf_save(scaled, icon_dst, "png", &save_error, nullptr)) {
      g_warning("Impossible d’écrire %s : %s", icon_dst, save_error->message);
    }
  }

  g_autofree gchar* apps_dir =
      g_build_filename(home, ".local", "share", "applications", nullptr);
  if (g_mkdir_with_parents(apps_dir, 0755) != 0) return;

  g_autofree gchar* desktop_path = g_build_filename(
      apps_dir, APPLICATION_ID ".desktop", nullptr);
  // Même CalVer que BuildInfo.version (injecté à la compile depuis le tag CI).
  g_autofree gchar* desktop = g_strdup_printf(
      "[Desktop Entry]\n"
      "Version=%s\n"
      "Type=Application\n"
      "Name=Podavio\n"
      "Comment=Lecteur de podcasts\n"
      "Exec=\"%s\"\n"
      "Icon=%s\n"
      "Terminal=false\n"
      "Categories=AudioVideo;Audio;Player;\n"
      "StartupWMClass=%s\n"
      "Keywords=podcast;audio;rss;\n",
      PODAVIO_DESKTOP_VERSION, exe_path, APPLICATION_ID, APPLICATION_ID);

  if (!g_file_set_contents(desktop_path, desktop, -1, &error)) {
    g_warning("Impossible d’écrire %s : %s", desktop_path, error->message);
    return;
  }

  // Rafraîchir les caches si les outils sont présents (best-effort).
  g_autofree gchar* update_desktop = g_strdup_printf(
      "update-desktop-database \"%s\" >/dev/null 2>&1", apps_dir);
  g_autofree gchar* icon_root =
      g_build_filename(home, ".local", "share", "icons", "hicolor", nullptr);
  g_autofree gchar* update_icons = g_strdup_printf(
      "gtk-update-icon-cache -f -t \"%s\" >/dev/null 2>&1", icon_root);
  g_spawn_command_line_async(update_desktop, nullptr);
  g_spawn_command_line_async(update_icons, nullptr);
}

static void set_podavio_icon(GtkWindow* window) {
  g_autofree gchar* icon_path = resolve_podavio_icon_path();
  if (icon_path == nullptr) {
    g_warning("Icône Podavio introuvable à côté du binaire");
    return;
  }

  g_autoptr(GError) error = nullptr;
  g_autoptr(GdkPixbuf) source = gdk_pixbuf_new_from_file(icon_path, &error);
  if (source == nullptr) {
    g_warning("Icône Podavio illisible : %s", error->message);
    return;
  }

  const int sizes[] = {256, 128, 64, 48, 32, 24, 16};
  GList* icons = nullptr;
  for (guint i = 0; i < G_N_ELEMENTS(sizes); i++) {
    GdkPixbuf* scaled = gdk_pixbuf_scale_simple(
        source, sizes[i], sizes[i], GDK_INTERP_BILINEAR);
    if (scaled != nullptr) {
      icons = g_list_append(icons, scaled);
    }
  }
  if (icons == nullptr) return;

  gtk_window_set_default_icon_list(icons);
  gtk_window_set_icon_list(window, icons);
  g_list_free_full(icons, g_object_unref);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
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
  // Avant l’enregistrement Wayland : le compositeur lie app_id → .desktop.
  install_wayland_desktop_entry();

  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
