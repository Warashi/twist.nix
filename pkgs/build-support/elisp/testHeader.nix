with builtins; let
  pkgs = import <nixpkgs> {};
  parseElispHeaders = import ./parseElispHeaders.nix {inherit (pkgs) lib;};
in
  pkgs.lib.runTests {
    testBasic = {
      expr = parseElispHeaders (readFile ./testdata/header-basic.el);
      expected = {
        summary = "A basic configuration framework for org mode";
        Author = "Akira Komamura <akira.komamura@gmail.com>";
        Version = "0.2.9";
        Package-Requires = "((emacs \"25.1\") (dash \"2.18\"))";
        URL = "https://github.com/akirak/org-starter";
      };
    };

    testCaseInsensitive = {
      expr = parseElispHeaders (readFile ./testdata/header-case-insensitive.el);
      expected = {
        summary = "A basic configuration framework for org mode";
        Author = "Akira Komamura <akira.komamura@gmail.com>";
        Package-Requires = "((emacs \"25.1\") (dash \"2.18\"))";
      };
    };

    testLicense = {
      expr = parseElispHeaders (readFile ./testdata/header-license.el);
      expected = {
        summary = "A basic configuration framework for org mode";
        Author = "Akira Komamura <akira.komamura@gmail.com>";
        SPDX-License-Identifier = "GPL-3.0-or-later";
      };
    };

    testAlmostNone = {
      expr = parseElispHeaders (readFile ./testdata/header-almost-none.el);
      expected = {
        Version = "0.1";
        Package-Requires = "((emacs \"25.1\") (dash \"2.18\"))";
      };
    };

    testMultiLine = {
      expr = parseElispHeaders (readFile ./testdata/header-multi-line.el);
      expected = {
        summary = "A basic configuration framework for org mode";
        Version = "0.2.9";
        Package-Requires = "((emacs \"25.1\") (dash \"2.18\"))";
        Author = [
          "Akira Komamura <akira.komamura@gmail.com>"
          "Someone from somewhere else <someone@galaxy.space>"
        ];
        Maintainer = [
          "My Son <myson@earth.net>"
          "Your Grandpa <yourgrandpa@earth.net>"
        ];
        URL = "https://github.com/akirak/org-starter";
      };
    };

    testNoLexical = {
      expr = parseElispHeaders (readFile ./testdata/header-no-lexical.el);
      expected = {
        summary = "A basic configuration framework for org mode";
        Author = "Akira Komamura <akira.komamura@gmail.com>";
      };
    };

    testAsteriskDesc = {
      expr = parseElispHeaders (readFile ./testdata/header-asterisk-desc.el);
      expected = {
        summary = "A library that contains *asterisk* in its description";
        Author = "Akira Komamura <akira.komamura@gmail.com>";
      };
    };

    testMiniEdit = {
      expr = parseElispHeaders (readFile ./testdata/header-miniedit.el);
      expected = {
        summary = "Enhanced editing for minibuffer fields.";
        Version = "2.0";
        # Author(s) is currently ignored, as it's not a conventional header
      };
    };
  }
