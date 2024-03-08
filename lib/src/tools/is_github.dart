// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

/// Returns true if the environment variable 'GITHUB_ACTIONS' is set.
bool get isGitHub =>
    (testIsGitHub ?? false) ||
    Platform.environment.containsKey('GITHUB_ACTIONS');

/// Use this to override isGitHub in tests. Don't forget to reset
bool? testIsGitHub;
