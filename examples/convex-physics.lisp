(in-package #:org.shirakumo.fraf.trial.examples)

(define-example convex-physics
  :title "Complex Physics Scenes"
  :superclasses (trial:physics-scene alloy:observable)
  :slots ((model :initform NIL :accessor model)
          (mesh :initform NIL :accessor mesh)
          (file :initform NIL :accessor file)
          (physics-system :initform (make-instance 'rigidbody-system :units-per-metre 0.1)))
  (enter (make-instance 'vertex-entity :vertex-array (// 'trial 'grid)) scene)
  (enter (make-instance 'editor-camera :location (VEC3 0.0 2.3 10) :fov 50 :move-speed 0.1) scene)
  (enter (make-instance 'directional-light :direction -vy3+) scene)
  (enter (make-instance 'ambient-light :color (vec3 0.2)) scene)
  (enter (make-instance 'gravity :gravity (vec 0 -10 0)) scene)
  (let ((render (make-instance 'pbr-render-pass))
        (map (make-instance 'ward)))
    (connect (port render 'color) (port map 'previous-pass) scene)))

(define-handler ((scene convex-physics-scene) mouse-press :after) ()
  (let ((ball (make-instance 'physics-sphere :location (location (camera scene))))
        (force (n*m (minv-affine (view-matrix)) (nv- (vec 0 2 -100) (location (camera scene))))))
    (nv+ (velocity ball) force)
    (enter-and-load ball scene +main+)))

(alloy:define-observable (setf model) (value alloy:observable))
(alloy:define-observable (setf mesh) (value alloy:observable))

(defmethod setup-ui ((scene convex-physics-scene) panel)
  (let ((layout (make-instance 'alloy:grid-layout :col-sizes '(120 140 T) :row-sizes '(30)))
        (focus (make-instance 'alloy:vertical-focus-list)))
    (alloy:enter "Load Model" layout :row 0 :col 0)
    (let ((button (alloy:represent "..." 'alloy:button :layout-parent layout :focus-parent focus)))
      (alloy:on alloy:activate (button)
        (let ((file (org.shirakumo.file-select:existing :title "Load Model File..."
                                                        :filter '(("Wavefront OBJ" "obj")
                                                                  ("glTF File" "gltf")
                                                                  ("glTF Binary" "glb"))
                                                        :default (file scene))))
          (when file (setf (file scene) file)))))
    (alloy:enter "Mesh" layout :row 1 :col 0)
    (let ((selector (alloy:represent (mesh scene) 'alloy:combo-set :value-set () :layout-parent layout :focus-parent focus)))
      (alloy:on model (model scene)
        (let ((meshes (if (typep model 'model) (list-meshes model) ())))
          (setf (alloy:value-set selector) meshes)
          (when meshes (setf (alloy:value selector) (first meshes)))))
      (alloy:on alloy:value (mesh selector)
        (setf (mesh scene) mesh)))
    (alloy:finish-structure panel layout focus)))

(defmethod (setf file) :before (file (scene convex-physics-scene))
  (setf (model scene) (generate-resources 'model-loader file)))

(defmethod (setf mesh) :before ((mesh mesh-data) (scene convex-physics-scene))
  (multiple-value-bind (all-vertices all-faces)
      (org.shirakumo.fraf.manifolds:normalize
       (reordered-vertex-data mesh '(location))
       (trial::simplify (index-data mesh) '(unsigned-byte 32))
       :threshold .000001)
    (flet ((make-mesh (hull)
             (make-convex-mesh :vertices (org.shirakumo.fraf.convex-covering:vertices hull)
                               :faces (org.shirakumo.fraf.convex-covering:faces hull))))
      (let* ((primitives (map 'vector #'make-mesh (org.shirakumo.fraf.convex-covering:decompose all-vertices all-faces)))
             (entity (make-instance 'physics-wall :vertex-array (make-vertex-array mesh NIL)
                                                  :physics-primitives primitives)))
        (enter entity scene))))
  (commit (scene +main+) (loader +main+)))
