(defpackage :wad-loader
  (:use :common-lisp :binary-reader :wad-types)
  (:export :wad-reader :wad-reader-init
	   :get-things :get-linedefs :get-vertexes :get-sectors
	   :get-lump-index))

(in-package :wad-loader)


(defclass wad-reader ()
  ((filepath
    :initarg  :filepath
    :initform "../data/DOOM.WAD"
    :accessor filepath)
   (file           :accessor file)
   (identification :accessor identification)
   (numlumps       :accessor numlumps)
   (infotableofs   :accessor infotableofs)
   (directory      :accessor wad-directory)))


(defmacro transfer-slot-values (slot-name from-object to-object)
  `(setf (slot-value ,to-object ',slot-name)
	 (slot-value ,from-object ',slot-name)))

(defmethod open-wadfile ((reader wad-reader))
  (setf (file reader) (open (filepath reader) :element-type '(unsigned-byte 8))))

(defmethod read-wadinfo ((reader wad-reader))
  (with-slots (file) reader
    (file-position file 0)
    (let ((wadinfo (read-value 'wadinfo file)))
      (setf (identification reader) (wad-types::identification wadinfo))
      (setf (numlumps       reader) (wad-types::numlumps       wadinfo))
      (setf (infotableofs   reader) (wad-types::infotableofs   wadinfo)))))

(defmethod read-directory ((reader wad-reader))
  (with-slots (file numlumps infotableofs directory) reader
    (file-position file infotableofs)
    (setf directory (read-value 'binary-element-list file
				:element-type 'filelump
				:length numlumps))))

(defmethod wad-reader-init (path)
  (let ((reader (make-instance 'wad-reader :filepath path)))
    (open-wadfile   reader)
    (read-wadinfo   reader)
    (read-directory reader)
    reader))

#|
(defmethod get-lump ((reader wad-reader) lump-name)
  (dolist (lump (wad-directory reader))
    (if (string= (name lump) lump-name)
	(return lump))))
|#
(defmethod get-lump-index ((reader wad-reader) lump-name)
  (with-slots (directory numlumps) reader
    (loop for lump in directory
	  for i from 0 upto (1- numlumps)
	  do (if (string= (wad-types::name lump) lump-name)
		 (return i)))))

(defmethod get-lump-by-index (wad-reader lump-index)
  (nth lump-index (wad-directory wad-reader)))


(defun get-map-lump-index (map-index lump-name)
  (+ map-index (position lump-name *map-lumps* :test #'string=) 1))
  

(defmethod get-lump-data (wad-reader lump-index &key (header-length 0) (element-type 'uint8) (sizeof-element 1))
  (let* ((lump  (get-lump-by-index wad-reader lump-index))
	 (count (/ (- (wad-types::size lump) header-length) sizeof-element)))
    (file-position (file wad-reader) (wad-types::filepos lump))
    (read-value 'binary-element-list (file wad-reader)
		:element-type element-type :length count)))

(defmacro define-get-map-lump (name lump-name element-type sizeof-element)
  `(defmethod ,name (wad-reader map-index)
     (let ((index (get-map-lump-index map-index ,lump-name)))
       (get-lump-data wad-reader index :header-length 0
				       :element-type ,element-type
				       :sizeof-element ,sizeof-element))))

(define-get-map-lump get-things   "THINGS"   'thing   10)
(define-get-map-lump get-linedefs "LINEDEFS" 'linedef 14)  
(define-get-map-lump get-vertexes "VERTEXES" 'vertex   4)
(define-get-map-lump get-sectors  "SECTORS"  'sector  26)

(defun print-sectors (sectors)
  (dolist (s sectors)
    (with-slots (wad-types::floorheight
		 wad-types::floorflat
		 wad-types::ceilingflat
		 wad-types::lightlevel) s
      (format t "fh: ~3a ff: ~8a cf: ~8a ll: ~3a~%"
	      wad-types::floorheight
	      wad-types::floorflat
	      wad-types::ceilingflat
	      wad-types::lightlevel))))

(defun print-linedefs (linedefs)
  (dolist (l linedefs)
    (with-slots (wad-types::v1
		 wad-types::v2
		 wad-types::tag
		 wad-types::sidenum1
		 wad-types::sidenum2) l
      (format t "v1: ~5a v2: ~5a tag: ~5a s1: ~5a s2: ~5a~%"
	      wad-types::v1
	      wad-types::v2
	      wad-types::tag
	      wad-types::sidenum1
	      wad-types::sidenum2))))
		 
