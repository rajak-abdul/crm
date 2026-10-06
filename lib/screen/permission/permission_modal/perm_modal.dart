class UserModel {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final RoleModel? role;
  final TenantLimitModel? tenantLimit;
  final String? currency;
  final PlanFeaturesModel? planFeatures;
  final bool needsPrivacyPolicy;
  final bool needsTerms;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    this.role,
    this.tenantLimit,
    this.currency,
    this.planFeatures,
    required this.needsPrivacyPolicy,
    required this.needsTerms,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      role: json['role'] != null
          ? RoleModel.fromJson(json['role'])
          : null,
      tenantLimit: json['tenantLimit'] != null
          ? TenantLimitModel.fromJson(json['tenantLimit'])
          : null,
      currency: json['currency'],
      planFeatures: json['planFeatures'] != null
          ? PlanFeaturesModel.fromJson(json['planFeatures'])
          : null,
      needsPrivacyPolicy: json['needsPrivacyPolicy'] ?? false,
      needsTerms: json['needsTerms'] ?? false,
    );
  }
  
}

class RoleModel {
  final String id;
  final String name;
  final String description;
  final PermissionsModel permissions;
  final String createdAt;
  final String updatedAt;

  RoleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      permissions: PermissionsModel.fromJson(
        json['permissions'] ?? {},
      ),
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

class PermissionsModel {
  final bool dashboard;
  final bool leads;
  final bool createLead;
  final bool dealsAll;
  final bool createDeal;
  final bool dealsPipeline;
  final bool invoices;
  final bool proposal;
  final bool documents;
  final bool activities;
  final bool activitiesCalendar;
  final bool activitiesList;
  final bool usersRoles;
  final bool adminAccess;
  final bool emailChat;
  final bool emailCampaigns;
  final bool whatsappChat;
  final bool reports;
  final bool settings;
  final bool streakLeaderboard;
  final bool assignedTasks;
  final bool taskManagement;
  final bool targetManagement;
  final bool myTargets;
  final bool meetings;
  final bool scheduleView;
  final bool dealAnalysis;
  final bool wonAnalysis;
  final bool lossAnalysis;
  final bool messages;

  PermissionsModel({
    this.dashboard = false,
    this.leads = false,
    this.createLead = false,
    this.dealsAll = false,
    this.createDeal = false,
    this.dealsPipeline = false,
    this.invoices = false,
    this.proposal = false,
    this.documents = false,
    this.activities = false,
    this.activitiesCalendar = false,
    this.activitiesList = false,
    this.usersRoles = false,
    this.adminAccess = false,
    this.emailChat = false,
    this.emailCampaigns = false,
    this.whatsappChat = false,
    this.reports = false,
    this.settings = false,
    this.streakLeaderboard = false,
    this.assignedTasks = false,
    this.taskManagement = false,
    this.targetManagement = false,
    this.myTargets = false,
    this.meetings = false,
    this.scheduleView = false,
    this.dealAnalysis = false,
    this.wonAnalysis = false,
    this.lossAnalysis = false,
    this.messages = false,
  });

  factory PermissionsModel.fromJson(Map<String, dynamic> json) {
    return PermissionsModel(
      dashboard: json['dashboard'] ?? false,
      leads: json['leads'] ?? false,
      createLead: json['create_lead'] ?? false,
      dealsAll: json['deals_all'] ?? false,
      createDeal: json['create_deal'] ?? false,
      dealsPipeline: json['deals_pipeline'] ?? false,
      invoices: json['invoices'] ?? false,
      proposal: json['proposal'] ?? false,
      documents: json['documents'] ?? false,
      activities: json['activities'] ?? false,
      activitiesCalendar: json['activities_calendar'] ?? false,
      activitiesList: json['activities_list'] ?? false,
      usersRoles: json['users_roles'] ?? false,
      adminAccess: json['admin_access'] ?? false,
      emailChat: json['email_chat'] ?? false,
      emailCampaigns: json['email_campaigns'] ?? false,
      whatsappChat: json['whatsapp_chat'] ?? false,
      reports: json['reports'] ?? false,
      settings: json['settings'] ?? false,
      streakLeaderboard: json['streak_leaderboard'] ?? false,
      assignedTasks: json['assigned_tasks'] ?? false,
      taskManagement: json['task_management'] ?? false,
      targetManagement: json['target_management'] ?? false,
      myTargets: json['my_targets'] ?? false,
      meetings: json['meetings'] ?? false,
      scheduleView: json['schedule_view'] ?? false,
      dealAnalysis: json['deal_analysis'] ?? false,
      wonAnalysis: json['won_analysis'] ?? false,
      lossAnalysis: json['loss_analysis'] ?? false,
      messages: json['messages'] ?? false,
    );
  }
}

class TenantLimitModel {
  final String planName;
  final int maxUsers;
  final String planEndDate;

  TenantLimitModel({
    required this.planName,
    required this.maxUsers,
    required this.planEndDate,
  });

  factory TenantLimitModel.fromJson(Map<String, dynamic> json) {
    return TenantLimitModel(
      planName: json['plan_name'] ?? '',
      maxUsers: json['max_users'] ?? 0,
      planEndDate: json['plan_end_date'] ?? '',
    );
  }
}

class PlanFeaturesModel {
  final bool dashboard;
  final bool leads;
  final bool createLead;
  final bool dealsAll;
  final bool createDeal;
  final bool dealsPipeline;
  final bool invoices;
  final bool proposal;
  final bool activities;
  final bool activitiesCalendar;
  final bool activitiesList;
  final bool usersRoles;
  final bool adminAccess;
  final bool emailChat;
  final bool emailCampaigns;
  final bool whatsappChat;
  final bool reports;
  final bool analytics;
  final bool settings;
  final bool streakLeaderboard;
  final bool assignedTasks;
  final bool taskManagement;
  final bool targetManagement;
  final bool meetings;
  final bool googleMeetSync;
  final bool zoomMeetings;
  final bool messages;
  final bool chatbot;
  final bool integrationFacebook;
  final bool integrationLinkedin;
  final bool integrationJustdial;
  final bool integrationIndiamart;
  final bool integration99acres;
  final bool integrationSulekha;
  final bool documents;
  final bool wonAnalysis;
  final bool lossAnalysis;
  final bool dealAnalysis;
  final bool scheduleView;
  final bool integrationInstagram;
  final bool integrationWhatsapp;
  final bool liveTracking;
  final bool deviceLoginRequests;

  PlanFeaturesModel({
    this.dashboard = false,
    this.leads = false,
    this.createLead = false,
    this.dealsAll = false,
    this.createDeal = false,
    this.dealsPipeline = false,
    this.invoices = false,
    this.proposal = false,
    this.activities = false,
    this.activitiesCalendar = false,
    this.activitiesList = false,
    this.usersRoles = false,
    this.adminAccess = false,
    this.emailChat = false,
    this.emailCampaigns = false,
    this.whatsappChat = false,
    this.reports = false,
    this.analytics = false,
    this.settings = false,
    this.streakLeaderboard = false,
    this.assignedTasks = false,
    this.taskManagement = false,
    this.targetManagement = false,
    this.meetings = false,
    this.googleMeetSync = false,
    this.zoomMeetings = false,
    this.messages = false,
    this.chatbot = false,
    this.integrationFacebook = false,
    this.integrationLinkedin = false,
    this.integrationJustdial = false,
    this.integrationIndiamart = false,
    this.integration99acres = false,
    this.integrationSulekha = false,
    this.documents = false,
    this.wonAnalysis = false,
    this.lossAnalysis = false,
    this.dealAnalysis = false,
    this.scheduleView = false,
    this.integrationInstagram = false,
    this.integrationWhatsapp = false,
    this.liveTracking = false,
    this.deviceLoginRequests = false,
  });

  factory PlanFeaturesModel.fromJson(Map<String, dynamic> json) {
    return PlanFeaturesModel(
      dashboard: json['dashboard'] ?? false,
      leads: json['leads'] ?? false,
      createLead: json['create_lead'] ?? false,
      dealsAll: json['deals_all'] ?? false,
      createDeal: json['create_deal'] ?? false,
      dealsPipeline: json['deals_pipeline'] ?? false,
      invoices: json['invoices'] ?? false,
      proposal: json['proposal'] ?? false,
      activities: json['activities'] ?? false,
      activitiesCalendar: json['activities_calendar'] ?? false,
      activitiesList: json['activities_list'] ?? false,
      usersRoles: json['users_roles'] ?? false,
      adminAccess: json['admin_access'] ?? false,
      emailChat: json['email_chat'] ?? false,
      emailCampaigns: json['email_campaigns'] ?? false,
      whatsappChat: json['whatsapp_chat'] ?? false,
      reports: json['reports'] ?? false,
      analytics: json['analytics'] ?? false,
      settings: json['settings'] ?? false,
      streakLeaderboard: json['streak_leaderboard'] ?? false,
      assignedTasks: json['assigned_tasks'] ?? false,
      taskManagement: json['task_management'] ?? false,
      targetManagement: json['target_management'] ?? false,
      meetings: json['meetings'] ?? false,
      googleMeetSync: json['google_meet_sync'] ?? false,
      zoomMeetings: json['zoom_meetings'] ?? false,
      messages: json['messages'] ?? false,
      chatbot: json['chatbot'] ?? false,
      integrationFacebook: json['integration_facebook'] ?? false,
      integrationLinkedin: json['integration_linkedin'] ?? false,
      integrationJustdial: json['integration_justdial'] ?? false,
      integrationIndiamart: json['integration_indiamart'] ?? false,
      integration99acres: json['integration_99acres'] ?? false,
      integrationSulekha: json['integration_sulekha'] ?? false,
      documents: json['documents'] ?? false,
      wonAnalysis: json['won_analysis'] ?? false,
      lossAnalysis: json['loss_analysis'] ?? false,
      dealAnalysis: json['deal_analysis'] ?? false,
      scheduleView: json['schedule_view'] ?? false,
      integrationInstagram: json['integration_instagram'] ?? false,
      integrationWhatsapp: json['integration_whatsapp'] ?? false,
      liveTracking: json['live_tracking'] ?? false,
      deviceLoginRequests: json['device_login_requests'] ?? false,
    );
  }
}