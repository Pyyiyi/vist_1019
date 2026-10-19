-- 校园访客系统 V1.0 · 跨域种子锚点（唯一真值）
-- 执行方式：手动执行 `npm run seed`（tsx db/seed.ts），不进入迁移。
-- 本文件登记全部跨上下文共用的实体 UUID 与中文业务值；各领域卡的 seeds/NN-*.sql 必须逐字引用，禁止自造别名。
-- 时区：Asia/Shanghai。锚点日期 D0 = 执行 npm run seed 的本地日期（Asia/Shanghai）；文档中的 2026-10-12 为 D0 示例，运行时按 D0 代入。

BEGIN;

-- ============================================================
-- 一、角色
-- ============================================================
INSERT INTO roles (code, name, description) VALUES
  ('admin',   '管理员',     '系统管理员，拥有全部权限'),
  ('guard',   '门卫',       '校门核验、放行、离校登记、异常上报'),
  ('host',    '被访教职工', '本人相关预约的查看、代提、审核'),
  ('visitor', '访客',       'H5 无账号，凭绑定令牌访问本人预约')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 二、权限点（context:resource:action）
-- ============================================================
INSERT INTO permissions (code, name, resource, action, description) VALUES
  ('pt:workbench:read',            '查看工作台',     'workbench',   'read',     '工作台 KPI 与待办'),
  ('pt:qr:manage',                 '管理入口二维码', 'entry-qr',    'manage',   '生成、下载、打印入口二维码'),
  ('visit:appointment:create',     '代提预约',       'appointment', 'create',   '后台代访客提交预约'),
  ('visit:appointment:read',       '查看预约',       'appointment', 'read',     '预约列表与详情'),
  ('visit:appointment:update',     '改期预约',       'appointment', 'update',   '修改预约时段'),
  ('visit:appointment:cancel',     '取消预约',       'appointment', 'cancel',   '取消未完结预约'),
  ('visit:review:read',            '查看审核',       'review',      'read',     '待审核列表'),
  ('visit:review:decide',          '审核决定',       'review',      'decide',   '同意或拒绝'),
  ('visit:review:reschedule',      '提议改期',       'review',      'reschedule','向访客提议新时段'),
  ('visit:gate:today:read',        '查看当日门口',   'gate-today',  'read',     '门口当日视图'),
  ('visit:gate:verify',            '现场核验',       'gate',        'verify',   '按凭证核验预约'),
  ('visit:gate:admit',             '放行登记',       'gate',        'admit',    '核销并登记进校'),
  ('visit:gate:depart',            '离校登记',       'gate',        'depart',   '登记离校'),
  ('visit:gate:walkin',            '现场登记',       'gate',        'walkin',   '无预约现场登记'),
  ('visit:gate:incident:report',   '上报异常',       'incident',    'report',   '上报门口异常'),
  ('visit:gate:incident:dispose',  '处置异常',       'incident',    'dispose',  '管理员处置异常'),
  ('report:ledger:read',           '查看台账',       'ledger',      'read',     '台账、在校清单、检索'),
  ('report:ledger:export',         '导出台账',       'ledger',      'export',   '导出 CSV/Excel 与打印'),
  ('report:stats:read',            '查看统计',       'stats',       'read',     '来访量与异常统计'),
  ('access:user:manage',           '管理账号',       'user',        'manage',   '账号增改、停用、重置密码'),
  ('access:role:read',             '查看角色权限',   'role',        'read',     '角色权限矩阵'),
  ('master:visitor-type:manage',   '管理访客类型',   'visitor-type','manage',   '访客类型增改停用'),
  ('master:blacklist:manage',      '管理黑名单',     'blacklist',   'manage',   '黑名单增删'),
  ('master:time-rule:manage',      '管理时段规则',   'time-rule',   'manage',   '可预约与禁入规则'),
  ('master:gate:manage',           '管理校门',       'gate',        'manage',   '校门增改停用'),
  ('master:host:manage',           '管理教职工名册', 'host',        'manage',   '名册增改停用'),
  ('master:reviewer-rule:manage',  '管理审核人配置', 'reviewer-rule','manage',  '审核人规则'),
  ('notify:notification:read',     '查看站内消息',   'notification','read',     '消息列表与已读'),
  ('notify:channel:manage',        '配置通知渠道',   'channel',     'manage',   '渠道开关'),
  ('system:param:manage',          '管理系统参数',   'param',       'manage',   '参数读写'),
  ('system:dictionary:manage',     '管理数据字典',   'dictionary',  'manage',   '字典增改停用'),
  ('compliance:audit:read',        '查看操作日志',   'audit',       'read',     '审计查询'),
  ('compliance:privacy:manage',    '管理个人信息',   'privacy',     'manage',   '留存配置与人工清除')
ON CONFLICT (code) DO NOTHING;

-- 管理员：全部权限点
INSERT INTO role_permissions (role_code, permission_code)
SELECT 'admin', code FROM permissions
ON CONFLICT DO NOTHING;

-- 门卫
INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('guard', 'pt:workbench:read'),
  ('guard', 'visit:gate:today:read'),
  ('guard', 'visit:gate:verify'),
  ('guard', 'visit:gate:admit'),
  ('guard', 'visit:gate:depart'),
  ('guard', 'visit:gate:walkin'),
  ('guard', 'visit:gate:incident:report'),
  ('guard', 'report:ledger:read'),
  ('guard', 'notify:notification:read')
ON CONFLICT DO NOTHING;

-- 被访教职工
INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('host', 'pt:workbench:read'),
  ('host', 'visit:appointment:create'),
  ('host', 'visit:appointment:read'),
  ('host', 'visit:appointment:update'),
  ('host', 'visit:appointment:cancel'),
  ('host', 'visit:review:read'),
  ('host', 'visit:review:decide'),
  ('host', 'visit:review:reschedule'),
  ('host', 'notify:notification:read')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 三、认证方式
-- ============================================================
INSERT INTO auth_types (code, name, description, enabled) VALUES
  ('password', '账号密码', '后台账号与教职工工号登录', true)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 四、教职工名册（H1 李明 / H2 王芳）
-- ============================================================
INSERT INTO hosts (id, name, employee_no, department, phone, status) VALUES
  ('33333333-3333-4333-8333-333333333333', '李明', 'T001', '教务处', '13900139001', 'active'),
  ('44444444-4444-4444-8444-444444444444', '王芳', 'T002', '学生处', '13900139002', 'active')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 五、后台账号（密码统一 abc@123）
-- ============================================================
INSERT INTO users (id, username, password_hash, display_name, role_code, host_id, phone, status) VALUES
  ('11111111-1111-4111-8111-111111111111', 'admin',   crypt('abc@123', gen_salt('bf', 10)), '系统管理员', 'admin', NULL, '13900139000', 'active'),
  ('22222222-2222-4222-8222-222222222222', 'guard01', crypt('abc@123', gen_salt('bf', 10)), '门卫张师傅', 'guard', NULL, '13900139003', 'active'),
  ('33333333-3333-4333-8333-333333333334', 'T001',    crypt('abc@123', gen_salt('bf', 10)), '李明',       'host',  '33333333-3333-4333-8333-333333333333', '13900139001', 'active'),
  ('44444444-4444-4444-8444-444444444445', 'T002',    crypt('abc@123', gen_salt('bf', 10)), '王芳',       'host',  '44444444-4444-4444-8444-444444444444', '13900139002', 'active')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 六、访客类型
-- ============================================================
INSERT INTO visitor_types (id, code, name, status, sort_order) VALUES
  ('55555555-5555-4555-8555-555555555551', 'parent',  '家长',     'active', 10),
  ('55555555-5555-4555-8555-555555555552', 'outsider','外来人员', 'active', 20),
  ('55555555-5555-4555-8555-555555555553', 'official','公务来访', 'active', 30)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 七、校门
-- ============================================================
INSERT INTO gates (id, code, name, status, sort_order) VALUES
  ('66666666-6666-4666-8666-666666666661', 'east', '东门', 'active', 10),
  ('66666666-6666-4666-8666-666666666662', 'south','南门', 'active', 20)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 八、黑名单（赵某某，证件号 320101198803034566）
-- ============================================================
INSERT INTO blacklist_entries (id, id_no, name, reason, expire_at, status) VALUES
  ('77777777-7777-4777-8777-777777777701', '320101198803034566', '赵某某',
   '多次强行闯入，拒不登记，经保卫处确认', ((CURRENT_DATE + INTERVAL '14 months')::date + TIME '23:59:59') AT TIME ZONE 'Asia/Shanghai', '有效')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 九、时段规则（周一至周日 07:00–18:00 可预约）
-- ============================================================
INSERT INTO time_rules (id, weekday, start_time, end_time, rule_type) VALUES
  ('77777777-7777-4777-8777-777777777711', 1, TIME '07:00', TIME '18:00', '可预约'),
  ('77777777-7777-4777-8777-777777777712', 2, TIME '07:00', TIME '18:00', '可预约'),
  ('77777777-7777-4777-8777-777777777713', 3, TIME '07:00', TIME '18:00', '可预约'),
  ('77777777-7777-4777-8777-777777777714', 4, TIME '07:00', TIME '18:00', '可预约'),
  ('77777777-7777-4777-8777-777777777715', 5, TIME '07:00', TIME '18:00', '可预约'),
  ('77777777-7777-4777-8777-777777777716', 6, TIME '07:00', TIME '18:00', '可预约'),
  ('77777777-7777-4777-8777-777777777717', 7, TIME '07:00', TIME '18:00', '可预约')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十、数据字典
-- ============================================================
INSERT INTO data_dictionary (id, dict_type, dict_key, dict_label, sort_order, status) VALUES
  ('77777777-7777-4777-8777-777777777721', '随行关系', 'family',   '家属', 10, 'active'),
  ('77777777-7777-4777-8777-777777777722', '随行关系', 'colleague','同事', 20, 'active'),
  ('77777777-7777-4777-8777-777777777723', '随行关系', 'friend',   '朋友', 30, 'active'),
  ('77777777-7777-4777-8777-777777777724', '随行关系', 'other',    '其他', 40, 'active'),
  ('77777777-7777-4777-8777-777777777725', '证件类型', 'id-card',  '身份证', 10, 'active'),
  ('77777777-7777-4777-8777-777777777726', '证件类型', 'other',    '其他证件', 20, 'active')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十一、系统参数
-- ============================================================
INSERT INTO system_config (config_key, config_value, value_type, description) VALUES
  ('entry_url',                          'http://localhost/h5/apply', 'string',  'H5 入口地址，二维码内容'),
  ('privacy_retention_days',             '90',   'number',  '个人信息展示层脱敏留存天数'),
  ('audit_retention_days',               '365',  'number',  '操作日志留存天数'),
  ('verification_buffer_minutes',        '15',   'number',  '预约时段前后核验缓冲分钟'),
  ('max_stay_minutes',                   '240',  'number',  '单次预约最长停留分钟'),
  ('min_stay_minutes',                   '15',   'number',  '单次预约最短停留分钟'),
  ('reschedule_confirm_timeout_hours',   '3',    'number',  '改期确认超时小时'),
  ('arrival_reminder_minutes',           '30',   'number',  '到访提醒提前分钟'),
  ('login_max_failures',                 '5',    'number',  '连续登录失败锁定阈值'),
  ('login_lock_minutes',                 '10',   'number',  '账号锁定时长分钟'),
  ('password_min_length',                '6',    'number',  '密码最小长度'),
  ('max_companions',                     '10',   'number',  '随行人数上限'),
  ('ledger_page_size_default',           '20',   'number',  '分页默认条数'),
  ('ledger_page_size_max',               '100',  'number',  '分页上限'),
  ('booking_default_start',              '07:00','string',  '无时段规则时的默认开始'),
  ('booking_default_end',                '18:00','string',  '无时段规则时的默认结束')
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================
-- 十二、通知渠道
-- ============================================================
INSERT INTO notification_channels (channel_code, enabled) VALUES
  ('站内', true),
  ('短信', false),
  ('企微', false)
ON CONFLICT (channel_code) DO NOTHING;

-- ============================================================
-- 十三、预约锚点（11 条，覆盖 8 个状态）
-- 主访客证件号：110101199003071233 陈晨 / 310101199002022349 刘洋·吴倩·冯雪 /
--              320101198803034566 赵某某·韩梅 / 330101198504045670 周敏·郑凯·蒋涛
-- ============================================================
INSERT INTO appointments
  (id, appoint_no, visitor_type_id, visitor_name, visitor_phone, visitor_id_no,
   host_id, reviewer_id, expected_gate_id, visit_start, visit_end, reason, plate_no,
   status, people_count, black_hit, reschedule_proposed_at, reject_reason, cancel_reason,
   checkin_at, checkout_at, created_by, created_at, updated_at)
VALUES
  -- P1 待审核
  ('88888888-8888-4888-8888-888888888801', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '001', '55555555-5555-4555-8555-555555555551',
   '陈晨', '13800138000', '110101199003071233',
   '33333333-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333334', NULL,
   (CURRENT_DATE + TIME '10:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '11:00:00') AT TIME ZONE 'Asia/Shanghai',
   '与班主任沟通孩子近期学习情况', '京A12345', '待审核', 2, false, NULL, NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '09:15:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '09:15:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P2 已通过
  ('88888888-8888-4888-8888-888888888802', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '002', '55555555-5555-4555-8555-555555555553',
   '刘洋', '13800138000', '310101199002022349',
   '44444444-4444-4444-8444-444444444444', '44444444-4444-4444-8444-444444444445', NULL,
   (CURRENT_DATE + TIME '10:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '11:00:00') AT TIME ZONE 'Asia/Shanghai',
   '递交合作办学材料', NULL, '已通过', 1, false, NULL, NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '10:20:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '14:05:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P3 待审核（被访人王芳，审核人李明）
  ('88888888-8888-4888-8888-888888888803', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '003', '55555555-5555-4555-8555-555555555552',
   '周敏', '13800138000', '330101198504045670',
   '44444444-4444-4444-8444-444444444444', '33333333-3333-4333-8333-333333333334', NULL,
   (CURRENT_DATE + TIME '14:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '15:00:00') AT TIME ZONE 'Asia/Shanghai',
   '送递学生体检报告', NULL, '待审核', 1, false, NULL, NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '11:00:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '11:00:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P4 已到访（在校中）
  ('88888888-8888-4888-8888-888888888804', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '004', '55555555-5555-4555-8555-555555555551',
   '孙浩', '13800138000', '110101199003071233',
   '33333333-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333334', NULL,
   (CURRENT_DATE + TIME '08:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '09:00:00') AT TIME ZONE 'Asia/Shanghai',
   '参加家长开放日', '京B67890', '已到访(在校中)', 1, false, NULL, NULL, NULL,
   (CURRENT_DATE + TIME '08:05:00') AT TIME ZONE 'Asia/Shanghai', NULL,
   NULL, ((CURRENT_DATE - 2) + TIME '16:30:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '08:05:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P5 已离校
  ('88888888-8888-4888-8888-888888888805', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '005', '55555555-5555-4555-8555-555555555552',
   '吴倩', '13800138000', '310101199002022349',
   '44444444-4444-4444-8444-444444444444', '44444444-4444-4444-8444-444444444445', NULL,
   (CURRENT_DATE + TIME '07:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '08:00:00') AT TIME ZONE 'Asia/Shanghai',
   '设备维护', NULL, '已离校', 1, false, NULL, NULL, NULL,
   (CURRENT_DATE + TIME '07:10:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '07:55:00') AT TIME ZONE 'Asia/Shanghai',
   NULL, ((CURRENT_DATE - 2) + TIME '09:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '07:55:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P6 已改期
  ('88888888-8888-4888-8888-888888888806', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '006', '55555555-5555-4555-8555-555555555551',
   '陈晨', '13800138000', '110101199003071233',
   '33333333-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333334', NULL,
   (CURRENT_DATE + TIME '14:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '15:00:00') AT TIME ZONE 'Asia/Shanghai',
   '与班主任沟通孩子近期学习情况', NULL, '已改期', 1, false,
   (CURRENT_DATE + TIME '08:30:00') AT TIME ZONE 'Asia/Shanghai', NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '08:40:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '08:30:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P7 已拒绝
  ('88888888-8888-4888-8888-888888888807', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '007', '55555555-5555-4555-8555-555555555552',
   '郑凯', '13800138000', '330101198504045670',
   '44444444-4444-4444-8444-444444444444', '44444444-4444-4444-8444-444444444445', NULL,
   (CURRENT_DATE + TIME '11:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '12:00:00') AT TIME ZONE 'Asia/Shanghai',
   '推销办公用品', NULL, '已拒绝', 1, false, NULL,
   '来访事由与被访人工作安排不符', NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '15:00:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '15:30:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P8 已过期
  ('88888888-8888-4888-8888-888888888808', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '008', '55555555-5555-4555-8555-555555555551',
   '冯雪', '13800138000', '310101199002022349',
   '33333333-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333334', NULL,
   (CURRENT_DATE + TIME '09:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '10:00:00') AT TIME ZONE 'Asia/Shanghai',
   '领取学生获奖证书', NULL, '已过期', 1, false, NULL, NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 2) + TIME '10:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '10:00:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P9 已取消
  ('88888888-8888-4888-8888-888888888809', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '009', '55555555-5555-4555-8555-555555555552',
   '蒋涛', '13800138000', '330101198504045670',
   '33333333-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333334', NULL,
   (CURRENT_DATE + TIME '13:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '14:00:00') AT TIME ZONE 'Asia/Shanghai',
   '归还借用设备', NULL, '已取消', 1, false, NULL, NULL,
   '行程调整，不再到访', NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '13:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '08:10:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P10 待审核（黑名单命中）
  ('88888888-8888-4888-8888-888888888810', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '010', '55555555-5555-4555-8555-555555555552',
   '韩梅', '13800138000', '320101198803034566',
   '44444444-4444-4444-8444-444444444444', '44444444-4444-4444-8444-444444444445', NULL,
   (CURRENT_DATE + TIME '15:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '16:00:00') AT TIME ZONE 'Asia/Shanghai',
   '面谈教学合作', NULL, '待审核', 1, true, NULL, NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '17:00:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '17:00:00') AT TIME ZONE 'Asia/Shanghai'),
  -- P11 已通过
  ('88888888-8888-4888-8888-888888888811', 'AP' || to_char(CURRENT_DATE,'YYYYMMDD') || '011', '55555555-5555-4555-8555-555555555553',
   '杨帆', '13800138000', '110101199003071233',
   '33333333-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333334', '66666666-6666-4666-8666-666666666661',
   (CURRENT_DATE + TIME '16:00:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '17:00:00') AT TIME ZONE 'Asia/Shanghai',
   '洽谈校际交流项目', NULL, '已通过', 1, false, NULL, NULL, NULL, NULL, NULL,
   NULL, ((CURRENT_DATE - 1) + TIME '18:00:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '18:20:00') AT TIME ZONE 'Asia/Shanghai')
ON CONFLICT (id) DO NOTHING;

-- P1 随行人员 1 人（people_count = 2）
INSERT INTO companions (id, appointment_id, name, relation, id_no, sort_order) VALUES
  ('99999999-9999-4999-8999-999999999901', '88888888-8888-4888-8888-888888888801',
   '陈小雨', '家属', '110101201503071234', 1)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十四、通行凭证（11 条，短码 100001–100011）
-- 已到访/已离校的凭证为已使用
-- ============================================================
INSERT INTO visit_credentials (id, appointment_id, short_code, usage_status, used_at) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', '88888888-8888-4888-8888-888888888801', '100001', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02', '88888888-8888-4888-8888-888888888802', '100002', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03', '88888888-8888-4888-8888-888888888803', '100003', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa04', '88888888-8888-4888-8888-888888888804', '100004', '已使用', (CURRENT_DATE + TIME '08:05:00') AT TIME ZONE 'Asia/Shanghai'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa05', '88888888-8888-4888-8888-888888888805', '100005', '已使用', (CURRENT_DATE + TIME '07:10:00') AT TIME ZONE 'Asia/Shanghai'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa06', '88888888-8888-4888-8888-888888888806', '100006', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa07', '88888888-8888-4888-8888-888888888807', '100007', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa08', '88888888-8888-4888-8888-888888888808', '100008', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa09', '88888888-8888-4888-8888-888888888809', '100009', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10', '88888888-8888-4888-8888-888888888810', '100010', '未使用', NULL),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11', '88888888-8888-4888-8888-888888888811', '100011', '未使用', NULL)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十五、告知记录（每条预约 2 份，共 22 条）
-- ============================================================
INSERT INTO consent_records (id, appointment_id, consent_type, confirmed_at, channel)
SELECT
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(((row_number() OVER (ORDER BY a.id) - 1) * 2 + t.n)::text, 12, '0')),
  a.id,
  CASE t.n WHEN 1 THEN '安全告知' ELSE '个人信息授权告知' END,
  a.created_at + (t.n || ' second')::interval,
  'H5'
FROM appointments a
CROSS JOIN (VALUES (1), (2)) AS t(n)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十六、通行记录（P4 进校 1 条；P5 进校 + 离校 2 条）
-- ============================================================
INSERT INTO passage_records (id, appointment_id, gate_id, record_type, occurred_at, operator_id) VALUES
  ('cccccccc-cccc-4ccc-8ccc-cccccccccc01', '88888888-8888-4888-8888-888888888804',
   '66666666-6666-4666-8666-666666666661', '进校', (CURRENT_DATE + TIME '08:05:00') AT TIME ZONE 'Asia/Shanghai',
   '22222222-2222-4222-8222-222222222222'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccc02', '88888888-8888-4888-8888-888888888805',
   '66666666-6666-4666-8666-666666666661', '进校', (CURRENT_DATE + TIME '07:10:00') AT TIME ZONE 'Asia/Shanghai',
   '22222222-2222-4222-8222-222222222222'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccc03', '88888888-8888-4888-8888-888888888805',
   '66666666-6666-4666-8666-666666666662', '离校', (CURRENT_DATE + TIME '07:55:00') AT TIME ZONE 'Asia/Shanghai',
   '22222222-2222-4222-8222-222222222222')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十七、异常（3 条：1 条待处理黑名单命中、1 条已处理、1 条已忽略）
-- ============================================================
INSERT INTO incidents (id, appointment_id, incident_type, status, description, reported_by, handled_by, disposition_note, handled_at, created_at, updated_at) VALUES
  ('dddddddd-dddd-4ddd-8ddd-dddddddddd01', '88888888-8888-4888-8888-888888888810',
   '黑名单命中', '待处理', '提交预约时证件号命中黑名单，等待管理员核实', '22222222-2222-4222-8222-222222222222',
   NULL, NULL, NULL, ((CURRENT_DATE - 1) + TIME '17:00:30') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '17:00:30') AT TIME ZONE 'Asia/Shanghai'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddd02', '88888888-8888-4888-8888-888888888807',
   '信息不符', '已处理', '来访人所述事由与预约登记不一致', '22222222-2222-4222-8222-222222222222',
   '11111111-1111-4111-8111-111111111111', '已联系被访人确认，该预约已拒绝', ((CURRENT_DATE - 1) + TIME '16:00:00') AT TIME ZONE 'Asia/Shanghai',
   ((CURRENT_DATE - 1) + TIME '15:20:00') AT TIME ZONE 'Asia/Shanghai', ((CURRENT_DATE - 1) + TIME '16:00:00') AT TIME ZONE 'Asia/Shanghai'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddd03', NULL,
   '强行闯入', '已忽略', '一名校外人员试图尾随进入，被门卫劝离，未造成后果', '22222222-2222-4222-8222-222222222222',
   '11111111-1111-4111-8111-111111111111', '经核实为附近居民误入，已口头教育并劝离', (CURRENT_DATE + TIME '06:40:00') AT TIME ZONE 'Asia/Shanghai',
   (CURRENT_DATE + TIME '06:30:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '06:40:00') AT TIME ZONE 'Asia/Shanghai')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十八、预约状态历史（每条预约 1 条创建记录；P5、P6 各补 1 条）
-- ============================================================
INSERT INTO appointment_status_history (id, appointment_id, from_status, to_status, changed_by, change_reason, occurred_at)
SELECT
  ('eeeeeeee-eeee-4eee-8eee-' || lpad((row_number() OVER (ORDER BY a.id))::text, 12, '0')),
  a.id, NULL, a.status,
  CASE WHEN a.status IN ('待审核') THEN a.reviewer_id ELSE a.reviewer_id END,
  CASE a.status
    WHEN '已拒绝' THEN '来访事由与被访人工作安排不符'
    WHEN '已取消' THEN '行程调整，不再到访'
    ELSE '提交预约'
  END,
  a.created_at
FROM appointments a
ON CONFLICT (id) DO NOTHING;

INSERT INTO appointment_status_history (id, appointment_id, from_status, to_status, changed_by, change_reason, occurred_at) VALUES
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01', '88888888-8888-4888-8888-888888888805', '已到访(在校中)', '已离校',
   '22222222-2222-4222-8222-222222222222', '离校登记', (CURRENT_DATE + TIME '07:55:00') AT TIME ZONE 'Asia/Shanghai'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeee02', '88888888-8888-4888-8888-888888888806', '待审核', '已改期',
   '33333333-3333-4333-8333-333333333334', '被访人提议改期至 14:00–15:00',
   (CURRENT_DATE + TIME '08:30:00') AT TIME ZONE 'Asia/Shanghai')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 十九、站内消息（3 条）
-- ============================================================
INSERT INTO notifications (id, recipient_type, recipient_id, recipient_name, recipient_phone, template_type, title, content, business_type, business_id, is_security, read_at, created_at) VALUES
  ('ffffffff-ffff-4fff-8fff-fffffffff001', 'user', '11111111-1111-4111-8111-111111111111', '系统管理员', '13900139000',
   '黑名单命中', '黑名单人员提交预约', '韩梅（证件号 3201**********4566）提交了 ' || to_char(CURRENT_DATE,'YYYY-MM-DD') || ' 15:00 的预约，已记录异常。', 'appointment', '88888888-8888-4888-8888-888888888810', true, NULL, ((CURRENT_DATE - 1) + TIME '17:00:30') AT TIME ZONE 'Asia/Shanghai'),
  ('ffffffff-ffff-4fff-8fff-fffffffff002', 'user', '22222222-2222-4222-8222-222222222222', '门卫张师傅', '13900139003',
   '黑名单命中', '黑名单人员提交预约', '韩梅（证件号 3201**********4566）提交了 ' || to_char(CURRENT_DATE,'YYYY-MM-DD') || ' 15:00 的预约，现场核验时将拦截。', 'appointment', '88888888-8888-4888-8888-888888888810', true, NULL, ((CURRENT_DATE - 1) + TIME '17:00:30') AT TIME ZONE 'Asia/Shanghai'),
  ('ffffffff-ffff-4fff-8fff-fffffffff003', 'user', '33333333-3333-4333-8333-333333333334', '李明', '13900139001',
   '改期提议', '您有一条预约等待访客确认改期', '陈晨的预约已改期至 ' || to_char(CURRENT_DATE,'YYYY-MM-DD') || ' 14:00–15:00，等待访客确认。', 'appointment', '88888888-8888-4888-8888-888888888806', false, (CURRENT_DATE + TIME '08:35:00') AT TIME ZONE 'Asia/Shanghai', (CURRENT_DATE + TIME '08:30:10') AT TIME ZONE 'Asia/Shanghai')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 二十、审计锚点（1 条 200 天前）
-- ============================================================
INSERT INTO operation_logs (id, user_id, user_name, occurred_at, object_type, object_id, action, result, before_value, after_value, ip, note) VALUES
  ('abababab-abab-4bab-8bab-ababababab01', '11111111-1111-4111-8111-111111111111', '系统管理员',
   ((CURRENT_DATE - 200) + TIME '09:30:00') AT TIME ZONE 'Asia/Shanghai', 'user', '22222222-2222-4222-8222-222222222222', '登录', '成功',
   NULL, '{"username":"guard01"}', '127.0.0.1', '锚点：留存超过 180 天的审计记录')
ON CONFLICT (id) DO NOTHING;

COMMIT;
