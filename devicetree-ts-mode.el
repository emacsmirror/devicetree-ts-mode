;;; devicetree-ts-mode.el --- tree-sitter support for DTS   -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Aleksandr Vityazev

;; Author: Aleksandr Vityazev <avityazew@gmail.com>
;; Keywords: devicetree tree-sitter

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; https://github.com/joelspadin/tree-sitter-devicetree
;;

;;; Code:


(require 'treesit)
(eval-when-compile (require 'rx))

(declare-function treesit-parser-create "treesit.c")
;; (declare-function treesit-induce-sparse-tree "treesit.c")
;; (declare-function treesit-node-child "treesit.c")
;; (declare-function treesit-node-child-by-field-name "treesit.c")
;; (declare-function treesit-node-start "treesit.c")
;; (declare-function treesit-node-type "treesit.c")

;; Taken from the dts-mode
(defvar devicetree-ts-mode--syntax-table
  (let ((table (make-syntax-table)))

    (modify-syntax-entry ?<  "(>" table)
    (modify-syntax-entry ?>  ")<" table)

    (modify-syntax-entry ?&  "." table)
    (modify-syntax-entry ?|  "." table)
    (modify-syntax-entry ?~  "." table)

    ;; _ and , are both symbol constituents.
    (modify-syntax-entry ?,  "_" table)
    (modify-syntax-entry ?_  "_" table)

    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)

    ;; Comments
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23"   table)
    (modify-syntax-entry ?\n "> b"    table)
    (modify-syntax-entry ?\^m "> b"   table)

    table)
  "Syntax table for `devicetree-ts-mode'.")

(defvar devicetree-ts-mode--treesit-keywords
  '("/delete-node/" "/delete-property/" "#define" "#include"
    "/omit-if-no-ref/" "/dts-v1/"))

(defvar devicetree-ts-mode--treesit-operators
  '( "!" "~" "-" "+" "*" "/" "%" "||" "&&" "|"
     "^" "&" "==" "!=" ">" ">=" "<=" ">" "<<" ">>"))

(defvar devicetree-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'devicetree
   :feature 'comment
   `((comment) @font-lock-comment-face
     (comment) @contextual)

   :language 'devicetree
   :feature 'string
   `((string_literal) @font-lock-string-face
     (system_lib_string) @font-lock-string-face)

   :language 'devicetree
   :feature 'keyword
   `([,@devicetree-ts-mode--treesit-keywords]
     @font-lock-keyword-face)

   :language 'devicetree
   :feature 'operator
   `([,@devicetree-ts-mode--treesit-operators]
     @font-lock-operator-face)

   ;; FIXME
   :language 'devicetree
   :override t
   :feature 'label
   `(;; (labeled_item label: (identifier) @font-lock-type-face)
     (labeled_item
      item:
      (node name: (identifier) @font-lock-type-face))
     (node
      name: (reference label: (identifier) @font-lock-type-face)))

   :language 'devicetree
   :feature 'bracket
   '((["(" ")" "<" ">" "{" "}"]) @font-lock-bracket-face)

   :language 'devicetree
   :feature 'delimiter
   '((["," ";"]) @font-lock-delimiter-face)

   :language 'devicetree
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings.")

(defun devicetree-ts-mode--node-address (node)
  "Return unit addresses for NODE concanated with @."
  (mapconcat (lambda (children)
               (if (string-equal (treesit-node-field-name children)
                                 "address")
                   (treesit-node-text children t)
                 ""))
             (treesit-node-children node)
             ""))

(defun devicetree-ts--mode--name-function (node)
  "Return name of NODE to use for in imenu."
  (let ((name (treesit-node-child-by-field-name node "name"))
        (address (treesit-node-child-by-field-name node "address")))
    (if address
        (concat (treesit-node-text name t)
                (devicetree-ts-mode--node-address node))
      (treesit-node-text name t))))


;;;###autoload
(define-derived-mode devicetree-ts-mode prog-mode "DTS"
  "Major mode for editing devicetree, powered by tree-sitter."
  :group 'devicetree
  :syntax-table devicetree-ts-mode--syntax-table

  (when (treesit-ready-p 'devicetree)
    (treesit-parser-create 'devicetree)

    ;; Comments.
    (setq-local comment-start "/* ")
    (setq-local comment-end " */")

    ;; Imenu.
    (setq-local treesit-simple-imenu-settings
                `((nil "\\`node\\'"
                       nil devicetree-ts--mode--name-function)))
    (setq-local which-func-functions nil)

    ;; Indent.
    ;; (setq-local treesit-simple-indent-rules
    ;;             devicetree-ts-mode--indent-rules)
    ;; (setq-local indent-tabs-mode t)

    ;; Electric
    (setq-local electric-indent-chars
                (append "{}<>[]" electric-indent-chars))

    ;; Navigation
    (setq-local treesit-thing-settings
                `((devicetree
                   (sexp (not ,(rx (or "{" "}" "<" ">" "[" "]" "," ";")))))))

    ;; Font-lock.
    (setq-local treesit-font-lock-settings
                devicetree-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment)
                  (keyword string)
                  (image-spec number)
                  (bracket delimiter error operator)))

    (treesit-major-mode-setup)))

(if (treesit-ready-p 'devicetree)
    (add-to-list 'auto-mode-alist
                 '("\\.dtsi?\\'" . devicetree-ts-mode)))

(provide 'devicetree-ts-mode)
;;; devicetree-ts-mode.el ends here
