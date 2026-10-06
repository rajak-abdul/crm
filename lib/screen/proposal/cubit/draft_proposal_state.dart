import '../modal/proposal_modal.dart';

abstract class DraftProposalState {
  const DraftProposalState();
}

class DraftProposalInitial extends DraftProposalState {
  const DraftProposalInitial();
}

class DraftProposalLoading extends DraftProposalState {
  const DraftProposalLoading();
}

class DraftProposalLoaded extends DraftProposalState {
  final List<Proposal> drafts;
  final String? sendingProposalId;

  const DraftProposalLoaded(
    this.drafts, {
    this.sendingProposalId,
  });
}

class DraftProposalError extends DraftProposalState {
  final String message;

  const DraftProposalError(this.message);
}

// ============================================================
// SEND DRAFT PROPOSAL
// ============================================================

class SendDraftProposalLoading extends DraftProposalState {
  final String proposalId;

  const SendDraftProposalLoading(
    this.proposalId,
  );
}

class SendDraftProposalSuccess extends DraftProposalState {
  final String message;
  final Proposal proposal;

  const SendDraftProposalSuccess({
    required this.message,
    required this.proposal,
  });
}

class SendDraftProposalError extends DraftProposalState {
  final String message;

  const SendDraftProposalError(
    this.message,
  );
}