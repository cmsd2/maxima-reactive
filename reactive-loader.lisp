;;; reactive-loader.lisp — Lisp helpers for the reactive package
;;;
;;; Holds the signal registry and exposes get/put/list/reset under
;;; Maxima-callable names with the `reactive-' prefix.  The .mac
;;; surface calls these via Maxima's `?identifier' Lisp escape.
;;;
;;; The registry is a single global hash table mapping signal name
;;; (string) to a Maxima list (name lo hi current kind).  Single
;;; table because we want O(1) lookup by name from collect_signals
;;; and the per-process scope is fine for v0 (no multi-session
;;; isolation needed; the kernel is the session).

(in-package :maxima)

(defvar *reactive-signals* (make-hash-table :test #'equal)
  "name (string) -> Maxima list (name lo hi current kind)")

(defun reactive-get-entry (name)
  "Lookup; return the Maxima-list entry, or NIL/false on miss."
  (or (gethash name *reactive-signals*) nil))

(defun reactive-put-entry (name entry)
  "Insert or replace the entry for NAME.  ENTRY is a Maxima list."
  (setf (gethash name *reactive-signals*) entry)
  entry)

(defun reactive-list-names ()
  "Return a Maxima list of every registered signal name, in
   insertion order.  Hash-tables are unordered in CL; we rely on
   the fact that we don't expose deletion, so maphash order is
   stable for a given history of inserts on SBCL but technically
   implementation-defined.  Sort for determinism so tests don't
   flap."
  (let ((names '()))
    (maphash (lambda (k v) (declare (ignore v)) (push k names))
             *reactive-signals*)
    (cons '(mlist simp) (sort names #'string<))))

(defun reactive-reset ()
  "Drop every registered signal.  Used by tests and
   notebook-restart code paths."
  (clrhash *reactive-signals*)
  t)
