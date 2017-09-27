(require 'cl-lib)
(require 'xterm-color)

(defface term-color-light-black
  '((t :foreground "#686868" :background "#686868"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-red
  '((t :foreground "#fb4933" :background "#fb4933"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-green
  '((t :foreground "#b8bb26" :background "#b8bb26"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-yellow
  '((t :foreground "#fabd2f" :background "#fabd2f"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-blue
  '((t :foreground "#83a598" :background "#83a598"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-magenta
  '((t :foreground "#d3869b" :background "#d3869b"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-cyan
  '((t :foreground "#3fd7e5" :background "#3fd7e5"))
  "Face used to render black color code."
  :group 'term)

(defface term-color-light-white
  '((t :foreground "#fdf4c1" :background "#fdf4c1"))
  "Face used to render black color code."
  :group 'term)

(defmacro term-256-color-define (number color)
  `(defface ,(intern (concat "term-color-" (number-to-string number)))
     '((t :foreground ,color :background ,color))
     (format "Color %s" ,number)))

(setq ansi-term-color-vector
      (vconcat
       [term
        term-color-black
        term-color-red
        term-color-green
        term-color-yellow
        term-color-blue
        term-color-magenta
        term-color-cyan
        term-color-white
        term-color-light-black
        term-color-light-red
        term-color-light-green
        term-color-light-yellow
        term-color-light-blue
        term-color-light-magenta
        term-color-light-cyan
        term-color-light-white]
       (cl-loop for j = 16 then (+ j 1)
                while (<= j 255)
                do (eval `(term-256-color-define ,j ,(xterm-color--256 j)))
                collect (intern (concat "term-color-" (number-to-string j))))))

(defvar term-ansi-disable-bold t)


(define-advice term-handle-colors-array (:override (parameter) 256-colors)
  (cond
   ;; 256
   ((and (= term-terminal-previous-parameter 5)
         (= term-terminal-previous-parameter-2 38)
         (>= parameter 0)
         (<= parameter 255))
    (setq term-ansi-current-color (+ parameter 1)))

   ((and (= term-terminal-previous-parameter 5)
         (= term-terminal-previous-parameter-2 48)
         (>= parameter 0)
         (<= parameter 255))
    (setq term-ansi-current-bg-color (+ parameter 1)))

   ;; Bold  (terminfo: bold)
   ((eq parameter 1)
    (setq term-ansi-current-bold t))

   ;; Underline
   ((eq parameter 4)
    (setq term-ansi-current-underline t))

   ;; Blink (unsupported by Emacs), will be translated to bold.
   ;; This may change in the future though.
   ((eq parameter 5)
    (setq term-ansi-current-bold t))

   ;; Reverse (terminfo: smso)
   ((eq parameter 7)
    (setq term-ansi-current-reverse t))

   ;; Invisible
   ((eq parameter 8)
    (setq term-ansi-current-invisible t))

   ;; Reset underline (terminfo: rmul)
   ((eq parameter 24)
    (setq term-ansi-current-underline nil))

   ;; Reset reverse (terminfo: rmso)
   ((eq parameter 27)
    (setq term-ansi-current-reverse nil))

   ;; ADDITION
   ((and (>= parameter 90) (<= parameter 97))
    (setq term-ansi-current-color (- parameter 81)))

   ;; Foreground
   ((and (>= parameter 30) (<= parameter 37))
    (setq term-ansi-current-color (- parameter 29)))

   ;; Reset foreground
   ((eq parameter 39)
    (setq term-ansi-current-color 0))

   ;; Background
   ((and (>= parameter 40) (<= parameter 47))
    (setq term-ansi-current-bg-color (- parameter 39)))


   ;; Reset background
   ((eq parameter 49)
    (setq term-ansi-current-bg-color 0))

   ;; 0 (Reset) or unknown (reset anyway)
   (t
    (term-ansi-reset)))

  ;; (message "Debug: U-%d R-%d B-%d I-%d D-%d F-%d B-%d"
  ;;          term-ansi-current-underline
  ;;          term-ansi-current-reverse
  ;;          term-ansi-current-bold
  ;;          term-ansi-current-invisible
  ;;          term-ansi-face-already-done
  ;;          term-ansi-current-color
  ;;          term-ansi-current-bg-color)

  (unless term-ansi-face-already-done
    (if term-ansi-current-invisible
        (let ((color
               (if term-ansi-current-reverse
                   (face-foreground
                    (elt ansi-term-color-vector term-ansi-current-color)
                    nil 'default)
                 (face-background
                  (elt ansi-term-color-vector term-ansi-current-bg-color)
                  nil 'default))))
          (setq term-current-face
                (list :background color
                      :foreground color))
          ) ;; No need to bother with anything else if it's invisible.
      (setq term-current-face
            (list :foreground
              (face-foreground
               (elt ansi-term-color-vector term-ansi-current-color)
               nil 'default)
              :background
              (face-background
               (elt ansi-term-color-vector term-ansi-current-bg-color)
               nil 'default)
              :inverse-video term-ansi-current-reverse))

      (when (and term-ansi-current-bold
                 (not term-ansi-disable-bold))
        (setq term-current-face
              `(,term-current-face :inherit term-bold)))

      (when (and term-ansi-disable-bold term-ansi-current-bold)
        (let ((pos (cl-position
                    (plist-get term-current-face :foreground)
                    (mapcar (lambda (face) (face-foreground face nil 'default))
                            (cl-subseq ansi-term-color-vector 1 9))
                    :test #'string=)))
          (if pos
              (plist-put term-current-face
                         :foreground
                         (face-foreground
                          (elt ansi-term-color-vector (+ pos 9)) nil 'default)))))

      (when term-ansi-current-underline
        (setq term-current-face
              `(,term-current-face :inherit term-underline)))))

  ;;	(message "Debug %S" term-current-face)
  ;; FIXME: shouldn't we set term-ansi-face-already-done to t here?  --Stef
  (setq term-ansi-face-already-done nil))

(setq term-termcap-format
  "%s%s:li#%d:co#%d:cl=\\E[H\\E[J:cd=\\E[J:bs:am:xn:cm=\\E[%%i%%d;%%dH\
:nd=\\E[C:up=\\E[A:ce=\\E[K:ho=\\E[H:pt\
:al=\\E[L:dl=\\E[M:DL=\\E[%%dM:AL=\\E[%%dL:cs=\\E[%%i%%d;%%dr:sf=^J\
:dc=\\E[P:DC=\\E[%%dP:IC=\\E[%%d@:im=\\E[4h:ei=\\E[4l:mi:\
:so=\\E[7m:se=\\E[m:us=\\E[4m:ue=\\E[m:md=\\E[1m:mr=\\E[7m:me=\\E[m\
:UP=\\E[%%dA:DO=\\E[%%dB:LE=\\E[%%dD:RI=\\E[%%dC\
:kl=\\EOD:kd=\\EOB:kr=\\EOC:ku=\\EOA:kN=\\E[6~:kP=\\E[5~:@7=\\E[4~:kh=\\E[1~\
:mk=\\E[8m:cb=\\E[1K:op=\\E[39;49m:Co#256:pa#32767:AB=\\E[48;5;%%dm:AF=\\E[38;5;%%dm:cr=^M\
:bl=^G:do=^J:le=^H:ta=^I:se=\\E[27m:ue=\\E[24m\
:kb=^?:kD=^[[3~:sc=\\E7:rc=\\E8:r1=\\Ec:")

(setq term-term-name "eterm-256color")