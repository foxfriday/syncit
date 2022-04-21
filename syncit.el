;;; syncit.el --- Sync calendar and contacts.

;;; Commentary:
;; Use `vdirsyncer` and `khard` to sync calendar events with Emacs' diary and
;; contacts with `ecomplete`. This is one directional as I have little need to
;; upload events from Emacs.

;;; Code:
(require 'ecomplete)
(require 'icalendar)

(defvar syncit-cal-dir "~/.calendar"
  "Calendar directory.")

(defvar syncit-diary-file ecomplete-database-file
  "Location of the import diary file.")

(defvar syncit-email-group nil
  "Email group to sync.")

(defun syncit-update-contacts ()
  "Add contacts to `ecomplete`."
  (let* ((khard "khard email --parsable --search-in-source-files --remove-first-line")
         (cntcs (split-string (shell-command-to-string khard) "\n")))
    (ecomplete-setup)
    (dolist-with-progress-reporter (row cntcs)
        "Updating contacts"
      (let* ((cntc (split-string row "\t"))
             (email (car-safe cntc))
             (name (if email (nth 1 cntc) nil))
             (group (if name (nth 2 cntc) nil))
             (addit (if syncit-email-group (string= syncit-email-group group) t)))
        (when (and addit email name)
          (ecomplete-add-item 'mail email (concat name " <" email ">")))))
    (ecomplete-save)))

(defun syncit-update-diary ()
  "Update diary file using `icalendar`."
  (let* ((dir syncit-cal-dir)
         (files (directory-files dir nil ".ics$"))
         (dest syncit-diary-file))
    (when (file-exists-p dest)
      (with-temp-file dest
        (erase-buffer)))
    (dolist-with-progress-reporter (file files)
        "Updating calendar"
      (with-temp-buffer
        (insert-file-contents (expand-file-name file dir))
        (icalendar-import-buffer dest t)))))

(defun syncit-update-diary-sentinel (process event)
  "Wait for inkscape PROCESS to close but has no use for EVENT."
  (when (memq (process-status process) '(exit signal))
    (syncit-update-contacts)
    (syncit-update-diary)))

;;;###autoload
(defun syncit-sync-diary ()
  "Edit and existing svg file named FSVG."
  (interactive)
  (let* ((log-buffer (get-buffer-create "*Messages*")))
    (make-process :name "vdirsyncer"
                  :buffer log-buffer
                  :command (list "vdirsyncer" "sync")
                  :stderr log-buffer
                  :sentinel 'syncit-update-diary-sentinel)))

(provide 'syncit)
;;; syncit.el ends here
