import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum BodyView { front, back }

enum Gender { male, female }

enum BodyMapMode { muscle, joint }

enum MuscleGroup {
  pecho,
  espalda,
  piernas,
  hombros,
  brazos,
  core,
  gluteos;

  String get displayName {
    switch (this) {
      case MuscleGroup.pecho:   return 'Pecho';
      case MuscleGroup.espalda: return 'Espalda';
      case MuscleGroup.piernas: return 'Piernas';
      case MuscleGroup.hombros: return 'Hombros';
      case MuscleGroup.brazos:  return 'Brazos';
      case MuscleGroup.core:    return 'Core';
      case MuscleGroup.gluteos: return 'Glúteos';
    }
  }

  Color get color {
    switch (this) {
      case MuscleGroup.pecho:   return const Color(0xFF3b82f6);
      case MuscleGroup.espalda: return const Color(0xFF8b5cf6);
      case MuscleGroup.piernas: return const Color(0xFF22c55e);
      case MuscleGroup.hombros: return const Color(0xFFf97316);
      case MuscleGroup.brazos:  return const Color(0xFFec4899);
      case MuscleGroup.core:    return const Color(0xFFeab308);
      case MuscleGroup.gluteos: return const Color(0xFFef4444);
    }
  }
}

enum MuscleSubgroup {
  // pecho
  pectoralSuperior, pectoralMedio, pectoralInferior,
  // espalda
  dorsalAncho, trapecioSuperior, trapecioMedio, romboides, redondoMayor, lumbarVisual,
  // piernas
  cuadriceps, isquiotibiales, aductores, gastrocnemio, soleo, tibialAnterior,
  // hombros
  deltoideAnterior, deltoideLateral, deltoidePosterior,
  // brazos
  bicepsBraquial, braquial, tricepsLarga, tricepsLateral, antebrazoFlexor, antebrazoExtensor,
  // core
  rectoAbdominalSuperior, rectoAbdominalInferior, oblicuos, cuello,
  // gluteos
  gluteoMayor, gluteoMedio;

  String get displayName {
    switch (this) {
      case MuscleSubgroup.pectoralSuperior:      return 'Pectoral superior';
      case MuscleSubgroup.pectoralMedio:         return 'Pectoral medio';
      case MuscleSubgroup.pectoralInferior:      return 'Pectoral inferior';
      case MuscleSubgroup.dorsalAncho:           return 'Dorsal ancho';
      case MuscleSubgroup.trapecioSuperior:      return 'Trapecio superior';
      case MuscleSubgroup.trapecioMedio:         return 'Trapecio medio';
      case MuscleSubgroup.romboides:             return 'Romboides';
      case MuscleSubgroup.redondoMayor:          return 'Redondo mayor';
      case MuscleSubgroup.lumbarVisual:          return 'Lumbar';
      case MuscleSubgroup.cuadriceps:            return 'Cuádriceps';
      case MuscleSubgroup.isquiotibiales:        return 'Isquiotibiales';
      case MuscleSubgroup.aductores:             return 'Aductores';
      case MuscleSubgroup.gastrocnemio:          return 'Gastrocnemio';
      case MuscleSubgroup.soleo:                 return 'Sóleo';
      case MuscleSubgroup.tibialAnterior:        return 'Tibial anterior';
      case MuscleSubgroup.deltoideAnterior:      return 'Deltoides anterior';
      case MuscleSubgroup.deltoideLateral:       return 'Deltoides lateral';
      case MuscleSubgroup.deltoidePosterior:     return 'Deltoides posterior';
      case MuscleSubgroup.bicepsBraquial:        return 'Bíceps braquial';
      case MuscleSubgroup.braquial:              return 'Braquial';
      case MuscleSubgroup.tricepsLarga:          return 'Tríceps (cab. larga)';
      case MuscleSubgroup.tricepsLateral:        return 'Tríceps (cab. lateral)';
      case MuscleSubgroup.antebrazoFlexor:       return 'Antebrazo flexor';
      case MuscleSubgroup.antebrazoExtensor:     return 'Antebrazo extensor';
      case MuscleSubgroup.rectoAbdominalSuperior: return 'Recto abd. superior';
      case MuscleSubgroup.rectoAbdominalInferior: return 'Recto abd. inferior';
      case MuscleSubgroup.oblicuos:              return 'Oblicuos';
      case MuscleSubgroup.cuello:                return 'Cuello';
      case MuscleSubgroup.gluteoMayor:           return 'Glúteo mayor';
      case MuscleSubgroup.gluteoMedio:           return 'Glúteo medio';
    }
  }
}

enum JointFamily {
  shoulder, elbow, wrist, hip, knee, ankle, cervical, lumbar;

  String get displayName {
    switch (this) {
      case JointFamily.shoulder:  return 'Hombro';
      case JointFamily.elbow:     return 'Codo';
      case JointFamily.wrist:     return 'Muñeca';
      case JointFamily.hip:       return 'Cadera';
      case JointFamily.knee:      return 'Rodilla';
      case JointFamily.ankle:     return 'Tobillo';
      case JointFamily.cervical:  return 'Cervical';
      case JointFamily.lumbar:    return 'Lumbar';
    }
  }
}

// ── Geometría ─────────────────────────────────────────────────────────────────

/// Punto normalizado (0–1) usado por PolygonShape.
class Point {
  final double x, y;
  const Point(this.x, this.y);
}

abstract class HitboxShape {
  const HitboxShape();
}

/// Elipse normalizada (0–1) con rotación opcional en grados.
///
/// Hit-test (ver pin tool): trasladar el punto al sistema local de la elipse,
/// rotar por -rot, y aplicar la fórmula estándar (lx²/rx²) + (ly²/ry²) ≤ 1.
class EllipseShape extends HitboxShape {
  final double cx, cy, rx, ry, rot;
  const EllipseShape({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.rot = 0,
  });
}

/// Polígono normalizado (0–1) — los vértices se proyectan al viewBox del SVG.
class PolygonShape extends HitboxShape {
  final List<Point> points;
  const PolygonShape({required this.points});
}

// ── Data classes ──────────────────────────────────────────────────────────────

class MuscleRegion {
  final String hitboxId;
  final MuscleGroup group;
  final MuscleSubgroup subgroup;
  final BodyView view;
  final HitboxShape shape;

  const MuscleRegion({
    required this.hitboxId,
    required this.group,
    required this.subgroup,
    required this.view,
    required this.shape,
  });
}

class JointPoint {
  final String jointId;
  final JointFamily family;
  final BodyView view;
  final double cx, cy;

  const JointPoint({
    required this.jointId,
    required this.family,
    required this.view,
    required this.cx,
    required this.cy,
  });
}

// ── Datos generados por GymUBB Body Map Pinner — 2026-04-26T19:30:02.671Z ─────
// Coordenadas normalizadas (0–1). Se proyectan al viewBox del SVG en uso.

const List<MuscleRegion> kMuscleRegions = [
  MuscleRegion(hitboxId: 'cuello_front', group: MuscleGroup.core, subgroup: MuscleSubgroup.cuello, view: BodyView.front, shape: EllipseShape(cx: 0.498, cy: 0.179, rx: 0.03, ry: 0.018, rot: 0)),
  MuscleRegion(hitboxId: 'pecho_sup_izq', group: MuscleGroup.pecho, subgroup: MuscleSubgroup.pectoralSuperior, view: BodyView.front, shape: EllipseShape(cx: 0.418, cy: 0.22, rx: 0.055, ry: 0.022, rot: 0)),
  MuscleRegion(hitboxId: 'pecho_sup_der', group: MuscleGroup.pecho, subgroup: MuscleSubgroup.pectoralSuperior, view: BodyView.front, shape: EllipseShape(cx: 0.582, cy: 0.217, rx: 0.055, ry: 0.022, rot: 0)),
  MuscleRegion(hitboxId: 'pecho_med_izq', group: MuscleGroup.pecho, subgroup: MuscleSubgroup.pectoralMedio, view: BodyView.front, shape: EllipseShape(cx: 0.414, cy: 0.247, rx: 0.06, ry: 0.02, rot: 0)),
  MuscleRegion(hitboxId: 'pecho_med_der', group: MuscleGroup.pecho, subgroup: MuscleSubgroup.pectoralMedio, view: BodyView.front, shape: EllipseShape(cx: 0.584, cy: 0.249, rx: 0.06, ry: 0.02, rot: 0)),
  MuscleRegion(hitboxId: 'pecho_inf_izq', group: MuscleGroup.pecho, subgroup: MuscleSubgroup.pectoralInferior, view: BodyView.front, shape: EllipseShape(cx: 0.418, cy: 0.277, rx: 0.058, ry: 0.018, rot: 0)),
  MuscleRegion(hitboxId: 'pecho_inf_der', group: MuscleGroup.pecho, subgroup: MuscleSubgroup.pectoralInferior, view: BodyView.front, shape: EllipseShape(cx: 0.578, cy: 0.276, rx: 0.058, ry: 0.018, rot: 0)),
  MuscleRegion(hitboxId: 'delt_ant_izq', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoideAnterior, view: BodyView.front, shape: EllipseShape(cx: 0.354, cy: 0.229, rx: 0.04, ry: 0.038, rot: 0)),
  MuscleRegion(hitboxId: 'delt_ant_der', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoideAnterior, view: BodyView.front, shape: EllipseShape(cx: 0.648, cy: 0.23, rx: 0.04, ry: 0.038, rot: 0)),
  MuscleRegion(hitboxId: 'delt_lat_izq_f', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoideLateral, view: BodyView.front, shape: EllipseShape(cx: 0.316, cy: 0.243, rx: 0.03, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'delt_lat_der_f', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoideLateral, view: BodyView.front, shape: EllipseShape(cx: 0.682, cy: 0.241, rx: 0.03, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'biceps_izq', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.bicepsBraquial, view: BodyView.front, shape: EllipseShape(cx: 0.275, cy: 0.316, rx: 0.038, ry: 0.06, rot: 28)),
  MuscleRegion(hitboxId: 'biceps_der', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.bicepsBraquial, view: BodyView.front, shape: EllipseShape(cx: 0.723, cy: 0.306, rx: 0.038, ry: 0.06, rot: 150)),
  MuscleRegion(hitboxId: 'braquial_izq', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.braquial, view: BodyView.front, shape: EllipseShape(cx: 0.247, cy: 0.344, rx: 0.02, ry: 0.04, rot: 25)),
  MuscleRegion(hitboxId: 'braquial_der', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.braquial, view: BodyView.front, shape: EllipseShape(cx: 0.754, cy: 0.337, rx: 0.02, ry: 0.04, rot: 150)),
  MuscleRegion(hitboxId: 'antebrazo_flex_izq', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.antebrazoFlexor, view: BodyView.front, shape: EllipseShape(cx: 0.189, cy: 0.401, rx: 0.04, ry: 0.075, rot: 25)),
  MuscleRegion(hitboxId: 'antebrazo_flex_der', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.antebrazoFlexor, view: BodyView.front, shape: EllipseShape(cx: 0.779, cy: 0.367, rx: 0.04, ry: 0.075, rot: 150)),
  MuscleRegion(hitboxId: 'abd_sup', group: MuscleGroup.core, subgroup: MuscleSubgroup.rectoAbdominalSuperior, view: BodyView.front, shape: EllipseShape(cx: 0.5, cy: 0.321, rx: 0.08, ry: 0.03, rot: 0)),
  MuscleRegion(hitboxId: 'abd_med', group: MuscleGroup.core, subgroup: MuscleSubgroup.rectoAbdominalSuperior, view: BodyView.front, shape: EllipseShape(cx: 0.498, cy: 0.374, rx: 0.08, ry: 0.03, rot: 0)),
  MuscleRegion(hitboxId: 'abd_inf', group: MuscleGroup.core, subgroup: MuscleSubgroup.rectoAbdominalInferior, view: BodyView.front, shape: EllipseShape(cx: 0.498, cy: 0.437, rx: 0.075, ry: 0.035, rot: 0)),
  MuscleRegion(hitboxId: 'oblicuo_izq', group: MuscleGroup.core, subgroup: MuscleSubgroup.oblicuos, view: BodyView.front, shape: EllipseShape(cx: 0.399, cy: 0.439, rx: 0.025, ry: 0.06, rot: 0)),
  MuscleRegion(hitboxId: 'oblicuo_der', group: MuscleGroup.core, subgroup: MuscleSubgroup.oblicuos, view: BodyView.front, shape: EllipseShape(cx: 0.597, cy: 0.438, rx: 0.025, ry: 0.06, rot: 0)),
  MuscleRegion(hitboxId: 'aductor_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.aductores, view: BodyView.front, shape: EllipseShape(cx: 0.46, cy: 0.58, rx: 0.025, ry: 0.055, rot: 0)),
  MuscleRegion(hitboxId: 'aductor_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.aductores, view: BodyView.front, shape: EllipseShape(cx: 0.54, cy: 0.58, rx: 0.025, ry: 0.055, rot: 0)),
  MuscleRegion(hitboxId: 'cuad_recto_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.cuadriceps, view: BodyView.front, shape: EllipseShape(cx: 0.407, cy: 0.602, rx: 0.04, ry: 0.09, rot: 0)),
  MuscleRegion(hitboxId: 'cuad_recto_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.cuadriceps, view: BodyView.front, shape: EllipseShape(cx: 0.584, cy: 0.612, rx: 0.04, ry: 0.09, rot: 0)),
  MuscleRegion(hitboxId: 'cuad_lat_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.cuadriceps, view: BodyView.front, shape: EllipseShape(cx: 0.364, cy: 0.595, rx: 0.025, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'cuad_lat_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.cuadriceps, view: BodyView.front, shape: EllipseShape(cx: 0.628, cy: 0.597, rx: 0.025, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'cuad_med_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.cuadriceps, view: BodyView.front, shape: EllipseShape(cx: 0.39, cy: 0.717, rx: 0.025, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'cuad_med_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.cuadriceps, view: BodyView.front, shape: EllipseShape(cx: 0.624, cy: 0.725, rx: 0.025, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'tibial_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.tibialAnterior, view: BodyView.front, shape: EllipseShape(cx: 0.365, cy: 0.834, rx: 0.022, ry: 0.07, rot: 0)),
  MuscleRegion(hitboxId: 'tibial_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.tibialAnterior, view: BodyView.front, shape: EllipseShape(cx: 0.632, cy: 0.828, rx: 0.022, ry: 0.07, rot: 0)),
  MuscleRegion(hitboxId: 'cuello_back', group: MuscleGroup.core, subgroup: MuscleSubgroup.cuello, view: BodyView.back, shape: EllipseShape(cx: 0.5, cy: 0.154, rx: 0.028, ry: 0.02, rot: 0)),
  MuscleRegion(hitboxId: 'trap_med_izq', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.trapecioMedio, view: BodyView.back, shape: EllipseShape(cx: 0.463, cy: 0.239, rx: 0.038, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'trap_med_der', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.trapecioMedio, view: BodyView.back, shape: EllipseShape(cx: 0.54, cy: 0.235, rx: 0.038, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'romboides', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.romboides, view: BodyView.back, shape: EllipseShape(cx: 0.5, cy: 0.265, rx: 0.045, ry: 0.03, rot: 0)),
  MuscleRegion(hitboxId: 'delt_post_izq', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoidePosterior, view: BodyView.back, shape: EllipseShape(cx: 0.344, cy: 0.231, rx: 0.04, ry: 0.035, rot: 0)),
  MuscleRegion(hitboxId: 'delt_post_der', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoidePosterior, view: BodyView.back, shape: EllipseShape(cx: 0.658, cy: 0.231, rx: 0.04, ry: 0.035, rot: 0)),
  MuscleRegion(hitboxId: 'delt_lat_izq_b', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoideLateral, view: BodyView.back, shape: EllipseShape(cx: 0.31, cy: 0.247, rx: 0.03, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'delt_lat_der_b', group: MuscleGroup.hombros, subgroup: MuscleSubgroup.deltoideLateral, view: BodyView.back, shape: EllipseShape(cx: 0.688, cy: 0.247, rx: 0.03, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'triceps_larga_izq', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.tricepsLarga, view: BodyView.back, shape: EllipseShape(cx: 0.294, cy: 0.311, rx: 0.035, ry: 0.055, rot: 25)),
  MuscleRegion(hitboxId: 'triceps_larga_der', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.tricepsLarga, view: BodyView.back, shape: EllipseShape(cx: 0.708, cy: 0.313, rx: 0.035, ry: 0.055, rot: 153)),
  MuscleRegion(hitboxId: 'triceps_lat_izq', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.tricepsLateral, view: BodyView.back, shape: EllipseShape(cx: 0.26, cy: 0.295, rx: 0.025, ry: 0.055, rot: 25)),
  MuscleRegion(hitboxId: 'triceps_lat_der', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.tricepsLateral, view: BodyView.back, shape: EllipseShape(cx: 0.738, cy: 0.309, rx: 0.025, ry: 0.055, rot: 156)),
  MuscleRegion(hitboxId: 'antebrazo_ext_izq', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.antebrazoExtensor, view: BodyView.back, shape: EllipseShape(cx: 0.183, cy: 0.4, rx: 0.04, ry: 0.08, rot: 33)),
  MuscleRegion(hitboxId: 'antebrazo_ext_der', group: MuscleGroup.brazos, subgroup: MuscleSubgroup.antebrazoExtensor, view: BodyView.back, shape: EllipseShape(cx: 0.797, cy: 0.387, rx: 0.04, ry: 0.08, rot: 150)),
  MuscleRegion(hitboxId: 'redondo_izq', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.redondoMayor, view: BodyView.back, shape: EllipseShape(cx: 0.395, cy: 0.245, rx: 0.025, ry: 0.02, rot: 0)),
  MuscleRegion(hitboxId: 'redondo_der', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.redondoMayor, view: BodyView.back, shape: EllipseShape(cx: 0.605, cy: 0.245, rx: 0.025, ry: 0.02, rot: 0)),
  MuscleRegion(hitboxId: 'lumbar_v', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.lumbarVisual, view: BodyView.back, shape: EllipseShape(cx: 0.5, cy: 0.385, rx: 0.06, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'gluteo_izq', group: MuscleGroup.gluteos, subgroup: MuscleSubgroup.gluteoMayor, view: BodyView.back, shape: EllipseShape(cx: 0.439, cy: 0.495, rx: 0.045, ry: 0.045, rot: 0)),
  MuscleRegion(hitboxId: 'gluteo_der', group: MuscleGroup.gluteos, subgroup: MuscleSubgroup.gluteoMayor, view: BodyView.back, shape: EllipseShape(cx: 0.553, cy: 0.492, rx: 0.045, ry: 0.045, rot: 0)),
  MuscleRegion(hitboxId: 'isquio_bf_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.isquiotibiales, view: BodyView.back, shape: EllipseShape(cx: 0.385, cy: 0.631, rx: 0.03, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'isquio_bf_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.isquiotibiales, view: BodyView.back, shape: EllipseShape(cx: 0.579, cy: 0.644, rx: 0.03, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'isquio_st_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.isquiotibiales, view: BodyView.back, shape: EllipseShape(cx: 0.429, cy: 0.638, rx: 0.025, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'isquio_st_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.isquiotibiales, view: BodyView.back, shape: EllipseShape(cx: 0.624, cy: 0.642, rx: 0.025, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'gastro_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.gastrocnemio, view: BodyView.back, shape: EllipseShape(cx: 0.372, cy: 0.805, rx: 0.033, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'gastro_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.gastrocnemio, view: BodyView.back, shape: EllipseShape(cx: 0.626, cy: 0.811, rx: 0.033, ry: 0.08, rot: 0)),
  MuscleRegion(hitboxId: 'soleo_izq', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.soleo, view: BodyView.back, shape: EllipseShape(cx: 0.369, cy: 0.922, rx: 0.025, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'soleo_der', group: MuscleGroup.piernas, subgroup: MuscleSubgroup.soleo, view: BodyView.back, shape: EllipseShape(cx: 0.628, cy: 0.922, rx: 0.025, ry: 0.04, rot: 0)),
  MuscleRegion(hitboxId: 'trap_sup', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.trapecioSuperior, view: BodyView.back, shape: PolygonShape(points: [Point(0.43, 0.17), Point(0.57, 0.17), Point(0.58, 0.205), Point(0.42, 0.205)])),
  MuscleRegion(hitboxId: 'dorsal_izq', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.dorsalAncho, view: BodyView.back, shape: PolygonShape(points: [Point(0.404, 0.251), Point(0.469, 0.261), Point(0.474, 0.346), Point(0.379, 0.331)])),
  MuscleRegion(hitboxId: 'dorsal_der', group: MuscleGroup.espalda, subgroup: MuscleSubgroup.dorsalAncho, view: BodyView.back, shape: PolygonShape(points: [Point(0.595, 0.25), Point(0.53, 0.26), Point(0.525, 0.345), Point(0.62, 0.33)])),
];

const List<JointPoint> kJointPoints = [
  JointPoint(jointId: 'cervical_front', family: JointFamily.cervical, view: BodyView.front, cx: 0.498, cy: 0.172),
  JointPoint(jointId: 'shoulder_izq_f', family: JointFamily.shoulder, view: BodyView.front, cx: 0.34,  cy: 0.226),
  JointPoint(jointId: 'shoulder_der_f', family: JointFamily.shoulder, view: BodyView.front, cx: 0.667, cy: 0.229),
  JointPoint(jointId: 'elbow_izq_f',    family: JointFamily.elbow,    view: BodyView.front, cx: 0.241, cy: 0.342),
  JointPoint(jointId: 'elbow_der_f',    family: JointFamily.elbow,    view: BodyView.front, cx: 0.758, cy: 0.35),
  JointPoint(jointId: 'wrist_izq_f',    family: JointFamily.wrist,    view: BodyView.front, cx: 0.132, cy: 0.458),
  JointPoint(jointId: 'wrist_der_f',    family: JointFamily.wrist,    view: BodyView.front, cx: 0.865, cy: 0.455),
  JointPoint(jointId: 'hip_izq_f',      family: JointFamily.hip,      view: BodyView.front, cx: 0.418, cy: 0.502),
  JointPoint(jointId: 'hip_der_f',      family: JointFamily.hip,      view: BodyView.front, cx: 0.582, cy: 0.502),
  JointPoint(jointId: 'knee_izq_f',     family: JointFamily.knee,     view: BodyView.front, cx: 0.378, cy: 0.72),
  JointPoint(jointId: 'knee_der_f',     family: JointFamily.knee,     view: BodyView.front, cx: 0.608, cy: 0.721),
  JointPoint(jointId: 'ankle_izq_f',    family: JointFamily.ankle,    view: BodyView.front, cx: 0.366, cy: 0.91),
  JointPoint(jointId: 'ankle_der_f',    family: JointFamily.ankle,    view: BodyView.front, cx: 0.632, cy: 0.908),
  JointPoint(jointId: 'cervical_back',  family: JointFamily.cervical, view: BodyView.back,  cx: 0.5,   cy: 0.15),
  JointPoint(jointId: 'shoulder_izq_b', family: JointFamily.shoulder, view: BodyView.back,  cx: 0.378, cy: 0.205),
  JointPoint(jointId: 'shoulder_der_b', family: JointFamily.shoulder, view: BodyView.back,  cx: 0.622, cy: 0.205),
  JointPoint(jointId: 'elbow_izq_b',    family: JointFamily.elbow,    view: BodyView.back,  cx: 0.232, cy: 0.354),
  JointPoint(jointId: 'elbow_der_b',    family: JointFamily.elbow,    view: BodyView.back,  cx: 0.765, cy: 0.349),
  JointPoint(jointId: 'wrist_izq_b',    family: JointFamily.wrist,    view: BodyView.back,  cx: 0.135, cy: 0.453),
  JointPoint(jointId: 'wrist_der_b',    family: JointFamily.wrist,    view: BodyView.back,  cx: 0.861, cy: 0.453),
  JointPoint(jointId: 'lumbar_back',    family: JointFamily.lumbar,   view: BodyView.back,  cx: 0.5,   cy: 0.395),
  JointPoint(jointId: 'hip_izq_b',      family: JointFamily.hip,      view: BodyView.back,  cx: 0.43,  cy: 0.475),
  JointPoint(jointId: 'hip_der_b',      family: JointFamily.hip,      view: BodyView.back,  cx: 0.57,  cy: 0.475),
  JointPoint(jointId: 'knee_izq_b',     family: JointFamily.knee,     view: BodyView.back,  cx: 0.39,  cy: 0.717),
  JointPoint(jointId: 'knee_der_b',     family: JointFamily.knee,     view: BodyView.back,  cx: 0.614, cy: 0.716),
  JointPoint(jointId: 'ankle_izq_b',    family: JointFamily.ankle,    view: BodyView.back,  cx: 0.372, cy: 0.93),
  JointPoint(jointId: 'ankle_der_b',    family: JointFamily.ankle,    view: BodyView.back,  cx: 0.629, cy: 0.926),
];

// ── BodyMapData — compatibilidad con exercise_card, exercise_detail, exercises_screen ──

class BodyMapData {
  BodyMapData._();

  static const Map<String, Color> muscleColors = {
    'Pecho':    Color(0xFF3b82f6),
    'Espalda':  Color(0xFF8b5cf6),
    'Piernas':  Color(0xFF22c55e),
    'Hombros':  Color(0xFFf97316),
    'Brazos':   Color(0xFFec4899),
    'Core':     Color(0xFFeab308),
    'Glúteos':  Color(0xFFef4444),
  };

  static const Map<String, String> muscleGroupDisplayName = {
    'pecho':   'Pecho',
    'espalda': 'Espalda',
    'piernas': 'Piernas',
    'hombros': 'Hombros',
    'brazos':  'Brazos',
    'core':    'Core',
    'gluteos': 'Glúteos',
  };

  static const Map<String, String> muscleEmoji = {
    'Pecho':   '💪',
    'Espalda': '🏋️',
    'Piernas': '🦵',
    'Hombros': '🔝',
    'Brazos':  '💪',
    'Core':    '⚡',
    'Glúteos': '🍑',
  };

  static const Map<String, String> jointFamilyNames = {
    'shoulder': 'Hombro',
    'elbow':    'Codo',
    'wrist':    'Muñeca',
    'hip':      'Cadera',
    'knee':     'Rodilla',
    'ankle':    'Tobillo',
    'cervical': 'Cervical',
    'lumbar':   'Lumbar',
  };
}
