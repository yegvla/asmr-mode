;;; asmr-mode.el --- mode for editing assembler code -*- lexical-binding: t; -*-

;; Copyright 2024 Vladislav Yegorov

;;; Commentary:

;; This mode is very close to the built-in asm-mode that comes with
;; Emacs already.  It does not go over the top with features, but just
;; adds some more sophisticated syntax-highlighting and better
;; compatibility with other assemblers.
;;
;; Most notably this mode changes the tab behavior to be more in line
;; with what Emacs usually does.  In this mode the tab behavior is
;; left untouched from the configured default.  Some people like to
;; have their arguments lined up in the same column (myself included),
;; so if the `asmr-tab-after-operation' variable is set to a non-nil
;; value then pressing space after an operation will automatically
;; indent to the next tab stop.
;;
;; This mode also heavily relies on your `tab-stop-list', if you want
;; for example all your operations to be aligned in the 20th column,
;; and the arguments in the 26th then you would set it to: '(20 26).
;; If your `tab-width' is 8 and you want operations to be on the 16th
;; column and arguments on the 24th, then just setting it '(16) would
;; be enough.

;;; Code:

(defvar asmr-mode-hook nil)

(defgroup asmr nil
  "Mode for editing assembler code."
  :link '(custom-group-link :tag "Font Lock Faces group" font-lock-faces)
  :group 'languages)

(defvar asmr-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?/  ". 124b" st)
    (modify-syntax-entry ?*  ". 23" st)
    st)
  "Syntax table used while in Asmr mode.")

(defvar-keymap asmr-mode-map
  :doc "Keymap for Asmr major mode."
  "<SPC>" #'asmr-electric-space
  ":" #'asmr-electric-colon
  "#" #'asmr-electric-hash
  "C-j" #'newline-and-indent
  "M-j" #'comment-indent-new-line)

(easy-menu-define asmr-mode-menu asmr-mode-map
  "Menu for Asmr mode."
  '("Asmr"
    ;; Actions for commenting
    ["Toggle Comment" comment-dwim
     :help "Comment or uncomment region"]
    ["Comment Region" comment-region
     :help "Comment each line in the region"]
    ["Uncomment Region" uncomment-region
     :help "Comment each line in the region"]))

(defcustom asmr-comment-style 'asmr-semicolon-style
  "The commenting style that asmr-mode should use.  As there are
many different variations of assembler syntax there is no common
comment convention.  You may also set this variable as a file
local variable if you like.

Included comment conventions are:

// A comment            asmr-c++-style
/* A comment */         asmr-c-style
; A comment             asmr-semicolon-style
# A comment             asmr-hash-style
* A comment             asmr-star-style
@ A comment             asmr-at-style"
  :type 'symbol
  :options '(asmr-c++-style
             asmr-c-style
             asmr-semicolon-style
             asmr-hash-style
             asmr-star-style
             asmr-at-style)
  :group 'asmr)

(defmacro asmr-define-char-style (name char)
  `(defun ,(intern (concat "asmr-" name "-style")) ()
     (interactive)
     (set-syntax-table (make-syntax-table asmr-mode-syntax-table))
     (modify-syntax-entry ,char "< b")
     (setq-local comment-start ,(char-to-string char))
     (setq-local comment-end "")
     (setq-local comment-add 1)))

(asmr-define-char-style "semicolon" ?\;)
(asmr-define-char-style "hash" ?\#)
(asmr-define-char-style "star" ?\*)
(asmr-define-char-style "at" ?\@)

(defun asmr-c-style ()
  (interactive)
  (set-syntax-table (make-syntax-table asmr-mode-syntax-table))
  (setq-local comment-start "/* ")
  (setq-local comment-end " */"))

(defun asmr-c++-style ()
  (interactive)
  (set-syntax-table (make-syntax-table asmr-mode-syntax-table))
  (setq-local comment-start "// ")
  (setq-local comment-end ""))

(defcustom asmr-colon-after-label t
  "Determines if asmr-mode should actually place a colon in your
buffer when used for a label.  If you set this to nil, then the
key for this command will still be the colon, it just wont type
it anymore when using it for a label.

Not recommended to turn it off as there would be now way to
distinguish an operation with arguments and a label, most
assemblers support optional colons even if it might not be the
recommended convention specified by the manufacturer."
  :tag "Place colon after label name"
  :local t
  :type 'boolean
  :group 'asmr)

(defcustom asmr-tab-after-operation t
  "Determines if asmr-mode should insert a tab when hitting space
after the operation.  The indentation is the next tab-stop."
  :tag "Tab after operation / before arguments"
  :local t
  :type 'boolean
  :group 'asmr)


(defcustom asmr-newline-after-label nil
  "Determines if asmr-mode should insert a new line after the label."
  :tag "Insert new line after label"
  :local t
  :type 'boolean
  :group 'asmr)


;; TODO: Cleanup
(defconst asmr-font-lock
  (append
   '(
     ;; Directive started from ".".
     ("^\\s *\\(\\.\\(\\sw\\|\\s_\\)+\\)\\_>[^:]"
      1 font-lock-preprocessor-face)
     ;; Labels starting with a period a usually local (not exported)
     ;; labels.  They are functionally similar to C labels and the
     ;; included c-mode highlights them with the constant face.
     ("^\\(\\.\\(?:\\sw\\|\\s_\\)+\\|[0-9]+\\)\\>:?[ \t]*\\(\\sw+\\(\\.\\sw+\\)*\\)?"
      (1 font-lock-constant-face) (2 font-lock-keyword-face nil t))
     ;; Usually it makes no sense to have a preprocessor statement
     ;; after a label, unless you want to reserve some space for a
     ;; variabe, so highlight this situation with the correct face.
     ("^\\(\\(\\sw\\|\\s_\\)+\\)\\>:?[ \t]*\\(\\.\\(\\sw\\|\\s_\\)+\\)"
      (1 font-lock-variable-name-face) (3 font-lock-preprocessor-face nil t))
     ;; Everything else is just a function.
     ("^\\(\\(\\sw\\|\\s_\\)+\\)\\>:?[ \t]*\\(\\sw+\\(\\.\\sw+\\)*\\)?"
      (1 font-lock-function-name-face) (3 font-lock-keyword-face nil t))
     ("^\\((\\sw+)\\)?\\s +\\(\\(\\.?\\sw\\|\\s_\\)+\\(\\.\\sw+\\)*\\)"
      2 font-lock-keyword-face)
     ;; Doc-comments
     ("^\\(\\s<\\{3,\\}\\|///\\).*" 0 font-lock-doc-face t)
     ;; TODO: No numbers as some assemblers use % for binary notation
     ;; %register for AT&T syntax.
     ("%\\sw+" . font-lock-variable-name-face))
   cpp-font-lock-keywords)
  "Additional expressions to highlight in Asmr mode.")

;;;###autoload
(define-derived-mode asmr-mode prog-mode "ASMR"
  "Major mode for editing assembler code."
  (setq-local font-lock-defaults '(asmr-font-lock))
  (set-syntax-table (make-syntax-table asmr-mode-syntax-table))
  (setq-local indent-line-function #'asmr-indent-line)
  (setq-local imenu-generic-expression
              '((nil "^\\([^0-9#]\\(?:\\sw\\|\\s_\\)+\\):?" 1)))

  ;; select comment style
  (funcall asmr-comment-style)
  (when (= (length comment-start) 1)
    (keymap-set asmr-mode-map comment-start 'asmr-electric-comment-char))

  (setq-local comment-start-skip "\\(?:\\s<+\\|/[/*]+\\)[ \t]*")
  (setq-local comment-end-skip "[ \t]*\\(\\s>\\|\\*+/\\)"))

(defun asmr-is-inside-comment (point)
  "Returns t if point is inside a comment, nil otherwise."
  (unless (eql point (point-min))
    (member (get-text-property (1- point) 'face)
            '(font-lock-doc-face
              font-lock-comment-face
              font-lock-comment-delimiter-face))))

(defun asmr-indent-line ()
  "Auto-indent the current line."
  (interactive)
  (let* ((savep (point))
         (indent (condition-case nil
                     (save-excursion
                       (forward-line 0)
                       (skip-chars-forward " \t")
                       (if (>= (point) savep) (setq savep nil))
                       (max (asmr-calculate-indentation) 0))
                   (error 0))))
    (if savep
        (save-excursion (indent-line-to indent))
      (indent-line-to indent))))

(defun asmr-calculate-indentation ()
  (or
   ;; Flush labels to the left margin.
   (and (looking-at "\\(\\.?\\sw\\|\\s_\\)+:") 0)
   ;; Do the same with macros.
   (and (looking-at "[ \t]*#") 0)
   ;; And with certain comments...
   (and (looking-at "\\s<\\{3,\\}") 0)
   ;; Simple `;' comments go to the comment-column.
   (and (looking-at "\\s<\\(\\S<\\|\\'\\)") comment-column)
   ;; The rest goes at the first tab stop.
   (indent-next-tab-stop 0)))

(defun asmr-c-fill-paragraph (&rest args)
  "Handles c-style multi-line comments.  Very hacky."
  (interactive)
  (when (asmr-is-inside-comment (point))
    (let* ((fill-paragraph-handle-comment t)
           (start (save-excursion (beginning-of-line 1) (point)))
           (continuation (save-excursion (beginning-of-line 1)
                                         (skip-syntax-forward " ")
                                         (eq (char-after) ?/)))
           (end (save-excursion (beginning-of-line 1)
                                (skip-syntax-forward " " (line-end-position))
                                (point)))
           (fill-prefix (concat (buffer-substring-no-properties start end)
                                (if continuation " " "") "* ")))
      (apply #'fill-paragraph args))))

(defun asmr-electric-space ()
  "If a space is inserted at the beginning of the line then
 automatically indent to the next tab-stop, if not this function
 will simply insert a space.  If the `asmr-tab-after-operation'
 setting is enabled also go to the next tab stop when hitting
 space after an operation."
  (interactive)
  (let ((col (current-column))
        (off (if tab-stop-list (car tab-stop-list) tab-width))
        (wid (if tab-stop-list
                 (if (eq (cdr tab-stop-list) nil)
                     tab-width
                   (- (car (cdr tab-stop-list)) (car tab-stop-list)))
               tab-width)))
    (if (or (bolp) (and (>= col off) (< col (+ off wid))
                        asmr-tab-after-operation
                        ;; Check if we are in a comment, if so don't
                        ;; insert a tab.
                        (not (asmr-is-inside-comment (point)))))
        (tab-to-tab-stop)
      (insert-char ?\ ))))

(defun asmr-electric-colon ()
  "If the preceding text could be a label then automatically indent
the label.  Depending on settings, add a colon and/or a newline."
  (interactive)
  (let ((labelp))
    (save-excursion
       (skip-syntax-backward "w_.")
       (skip-syntax-backward " ")
       (when (setq labelp (bolp))
         (delete-horizontal-space)))
    (when (or asmr-colon-after-label (not labelp))
      (insert-char ?\:))
    (when labelp
      (tab-to-tab-stop)
      (when asmr-newline-after-label
        (insert-char ?\n)))))

(defun asmr-electric-hash ()
  "Remove preceding white-space when typing a hash, usually used
 for macros in the GNU assembler."
  (interactive)
  (when (looking-back "^[ \t]+")
    (skip-syntax-backward " ")
    (delete-horizontal-space))
  (insert-char ?\#))

(defun asmr-electric-comment-char ()
  "This method is a re-implementation (the core behavior is the
same but its different) of the asm-comment function from
asm-mode.  It will automatically be assigned to the comment
character of the current style if the style consists of a single
character."
  (interactive)
  (cond
   ;; If cursor is right after a comment start sequence, place it at
   ;; the next line and optionally add a repetition character if
   ;; specified by the style.
   ((save-excursion
      (skip-syntax-backward " ")
      (if (< (skip-syntax-backward "<") 0)
          (and (not (bolp)) (not (asmr-is-inside-comment (point))))
        nil))
    (skip-syntax-backward " <")
    (comment-indent-new-line)
    (when (> comment-add 0)
      (insert comment-start))
    (comment-indent)
    (just-one-space))
   ;; Upgrade second-level and higher comments.
   ((save-excursion
      (skip-syntax-backward " ")
      (if (not (bolp))
          (and (< (skip-syntax-backward " <") 0) (bolp))
        nil))
    (save-excursion
      (beginning-of-line)
      (delete-horizontal-space)
      (self-insert-command 1))
    (just-one-space))
   ;; If cursor is not right after a comment start but still inside a
   ;; comment just insert the key normally.
   ((asmr-is-inside-comment (point))
    (self-insert-command 1))
   ;; Just leverage comment-dwim in any other case.
   (t (comment-dwim nil))))

(provide 'asmr-mode)
