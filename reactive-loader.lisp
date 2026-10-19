;;; reactive-loader.lisp — Lisp helpers for the reactive package
;;;
;;; Holds the signal registry and exposes get/put/list/reset under
;;; Maxima-callable names with the `reactive-' prefix.  The .mac
;;; surface calls these via Maxima's `?identifier' Lisp escape.
;;;
;;; The registry is a single global hash table mapping signal name
;;; (string) to a Maxima list of `key = value' equations, e.g.
;;;   [name = "freq", kind = slider, lo = 0.1, hi = 5.0, value = 0.1]
;;; Dropdowns add `choices = [...]'.  Keyed fields let new widget
;;; kinds add fields without shifting existing ones.  Single table
;;; because we want O(1) lookup by name from collect_signals and the
;;; per-process scope is fine for v0 (no multi-session isolation
;;; needed; the kernel is the session).
;;;
;;; A signal appears in expressions as the noun form %signal(SYM),
;;; where SYM is interned in the REACTIVE-SIGNALS package rather than
;;; MAXIMA.  Two reasons:
;;;   - a string argument breaks Maxima's sign and limit code (a
;;;     Lisp type error inside `limit' and definite `integrate');
;;;     a symbol argument does not.
;;;   - the Maxima reader never interns into REACTIVE-SIGNALS, so a
;;;     user variable called `freq' can't capture the signal's
;;;     argument when an expression is re-evaluated with `ev'.

(in-package :maxima)

(defpackage :reactive-signals (:use))

(defvar *reactive-signals* (make-hash-table :test #'equal)
  "name (string) -> Maxima list of key = value equations")

(defun reactive-valid-name-p (name)
  "True iff NAME is a non-empty string of at most 128 ASCII letters,
   digits and underscores.  Matches the check the aximar host applies
   before it calls signal_set, so a name accepted here always works
   in the UI round trip."
  (and (stringp name)
       (< 0 (length name) 129)
       (every (lambda (c)
                (and (char< c (code-char 128))
                     (or (alphanumericp c) (char= c #\_))))
              name)))

(defun reactive-symbol (name)
  "The REACTIVE-SIGNALS symbol that stands for signal NAME.  Applies
   the reader's case inversion so `freq' prints as freq, not FREQ."
  (intern (concatenate 'string "$" (maybe-invert-string-case name))
          :reactive-signals))

(defun reactive-symbol-p (x)
  "True iff X is a symbol made by reactive-symbol."
  (and (symbolp x) x
       (eq (symbol-package x) (find-package :reactive-signals))))

(defun reactive-symbol-name (sym)
  "Inverse of reactive-symbol: the signal name string for SYM."
  (maybe-invert-string-case (subseq (symbol-name sym) 1)))

(defun reactive-get-entry (name)
  "Lookup; return the Maxima-list entry, or NIL/false on miss."
  (or (gethash name *reactive-signals*) nil))

(defun reactive-put-entry (name entry)
  "Insert or replace the entry for NAME.  ENTRY is a Maxima list."
  (setf (gethash name *reactive-signals*) entry)
  entry)

(defun reactive-list-names ()
  "Return a Maxima list of every registered signal name, sorted
   by name.  Hash-tables are unordered in CL, so sort for
   determinism so tests don't flap."
  (let ((names '()))
    (maphash (lambda (k v) (declare (ignore v)) (push k names))
             *reactive-signals*)
    (cons '(mlist simp) (sort names #'string<))))

(defun reactive-reset ()
  "Drop every registered signal.  Used by tests and
   notebook-restart code paths."
  (clrhash *reactive-signals*)
  t)
