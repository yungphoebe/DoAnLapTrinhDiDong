class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.level,
  });

  final String id;
  final String name;
  final String description;
  final int sets;
  final int reps;
  final int restSeconds;
  final String level;
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.exercises,
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final List<Exercise> exercises;
}

const squat = Exercise(
  id: 'squat',
  name: 'Barbell Squat',
  description: 'Giữ lưng trung lập, đẩy hông ra sau và hạ xuống có kiểm soát.',
  sets: 3,
  reps: 12,
  restSeconds: 60,
  level: 'Cơ bản',
);

const legPress = Exercise(
  id: 'leg_press',
  name: 'Leg Press',
  description: 'Đặt chân vững trên bàn đạp, không khóa gối khi đẩy.',
  sets: 3,
  reps: 12,
  restSeconds: 60,
  level: 'Cơ bản',
);

const walkingLunge = Exercise(
  id: 'walking_lunge',
  name: 'Walking Lunge',
  description: 'Bước dài vừa phải và giữ đầu gối trước cùng hướng với mũi chân.',
  sets: 3,
  reps: 10,
  restSeconds: 60,
  level: 'Cơ bản',
);

const legExtension = Exercise(
  id: 'leg_extension',
  name: 'Leg Extension',
  description: 'Nâng tạ bằng cơ đùi, dừng ngắn ở điểm cao nhất.',
  sets: 3,
  reps: 12,
  restSeconds: 60,
  level: 'Cơ bản',
);

const benchPress = Exercise(
  id: 'bench_press',
  name: 'Bench Press',
  description: 'Hạ tạ về ngực dưới và giữ hai bả vai ổn định trên ghế.',
  sets: 3,
  reps: 10,
  restSeconds: 90,
  level: 'Trung cấp',
);

const latPulldown = Exercise(
  id: 'lat_pulldown',
  name: 'Lat Pulldown',
  description: 'Kéo thanh về ngực, không giật người hoặc ngả lưng quá mức.',
  sets: 3,
  reps: 12,
  restSeconds: 60,
  level: 'Trung cấp',
);

const shoulderPress = Exercise(
  id: 'shoulder_press',
  name: 'Shoulder Press',
  description: 'Giữ thân người ổn định và đẩy tạ theo đường thẳng.',
  sets: 3,
  reps: 10,
  restSeconds: 60,
  level: 'Trung cấp',
);

const dumbbellRow = Exercise(
  id: 'dumbbell_row',
  name: 'Dumbbell Row',
  description: 'Giữ lưng phẳng, kéo khuỷu tay về phía hông.',
  sets: 3,
  reps: 12,
  restSeconds: 60,
  level: 'Trung cấp',
);

const bicepsCurl = Exercise(
  id: 'biceps_curl',
  name: 'Biceps Curl',
  description: 'Giữ khuỷu tay sát thân và không đung đưa người.',
  sets: 3,
  reps: 12,
  restSeconds: 45,
  level: 'Trung cấp',
);

const workoutPlans = [
  WorkoutPlan(
    id: 'lower-body',
    title: 'Hủy Diệt Cơ Đùi',
    description: 'Tập trung vào đùi trước, đùi sau và mông.',
    level: 'Cơ bản',
    exercises: [squat, legPress, walkingLunge, legExtension],
  ),
  WorkoutPlan(
    id: 'upper-body',
    title: 'Sức Mạnh Thân Trên',
    description: 'Phát triển ngực, lưng, vai và tay.',
    level: 'Trung cấp',
    exercises: [benchPress, latPulldown, shoulderPress, dumbbellRow, bicepsCurl],
  ),
];
