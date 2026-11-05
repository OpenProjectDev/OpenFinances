import 'package:flutter/material.dart';

/// Title-less app bar for the main tab pages: keeps content clear of the
/// status bar (and keeps status-bar icon contrast) without a page title.
PreferredSizeWidget bareAppBar() =>
    AppBar(toolbarHeight: 8, automaticallyImplyLeading: false);
