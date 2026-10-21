*"* Local types of behavior pool ZBP_I_ASSET_LOAN_REQUEST
*"* (ADT: open the class -> tab "Local Types")

"=====================================================================
" Shared helper: logic used by more than one entity
"=====================================================================
CLASS lcl_helper DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_request_keys TYPE TABLE FOR READ IMPORT zi_asset_loan_request.

    "! DET-003: approver = active ZRAP_ASSET_APPR entry for the request
    "! department and the item category with the highest priority (1 = highest)
    CLASS-METHODS determine_approver IMPORTING keys TYPE tt_request_keys.

    "! DET-004: derive item status and request status from approved
    "! quantities and assignment states
    CLASS-METHODS recalc_status IMPORTING keys TYPE tt_request_keys.
ENDCLASS.

CLASS lcl_helper IMPLEMENTATION.

  METHOD determine_approver.
    CHECK keys IS NOT INITIAL.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( DepartmentID ApproverID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      ENTITY Request BY \_Items
        FIELDS ( RequestUUID CategoryID ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Request.

    LOOP AT requests INTO DATA(request).
      DATA(new_approver) = VALUE zrap_asset_req_h-approver_id( ).
      DATA(best_priority) = 999.

      LOOP AT items INTO DATA(item) WHERE RequestUUID = request-RequestUUID
                                      AND %is_draft   = request-%is_draft.
        SELECT SINGLE FROM zrap_asset_appr AS appr
               INNER JOIN zrap_asset_cat AS cat ON cat~category_id = appr~category_id
               FIELDS appr~approver_id, cat~priority
               WHERE appr~department_id = @request-DepartmentID
                 AND appr~category_id   = @item-CategoryID
                 AND appr~is_active     = @abap_true
                 AND cat~is_active      = @abap_true
               INTO @DATA(config).
        IF sy-subrc = 0 AND config-priority < best_priority.
          best_priority = config-priority.
          new_approver  = config-approver_id.
        ENDIF.
      ENDLOOP.

      IF new_approver <> request-ApproverID.
        APPEND VALUE #( %tky = request-%tky ApproverID = new_approver ) TO updates.
      ENDIF.
    ENDLOOP.

    CHECK updates IS NOT INITIAL.
    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request UPDATE FIELDS ( ApproverID ) WITH updates.
  ENDMETHOD.


  METHOD recalc_status.
    CHECK keys IS NOT INITIAL.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( Status CompletionDate ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      ENTITY Request BY \_Items
        FIELDS ( RequestUUID ApprovedQuantity ItemStatus ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item BY \_Assignments
        FIELDS ( ItemUUID AssignmentStatus ) WITH CORRESPONDING #( items )
        RESULT DATA(assignments).

    DATA request_updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Request.
    DATA item_updates    TYPE TABLE FOR UPDATE zi_asset_loan_request\\Item.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT requests INTO DATA(request).
      " Only statuses after approval are derived automatically
      IF request-Status <> zif_asset_loan_const=>request_status-approved
     AND request-Status <> zif_asset_loan_const=>request_status-asset_assigned
     AND request-Status <> zif_asset_loan_const=>request_status-checked_out
     AND request-Status <> zif_asset_loan_const=>request_status-partially_returned.
        CONTINUE.
      ENDIF.

      DATA(total_needed)   = 0.
      DATA(total_assigned) = 0.
      DATA(total_open)     = 0.
      DATA(total_closed)   = 0.

      LOOP AT items INTO DATA(item) WHERE RequestUUID = request-RequestUUID
                                      AND %is_draft   = request-%is_draft.
        DATA(assigned) = 0.
        DATA(open)     = 0.
        DATA(closed)   = 0.
        LOOP AT assignments INTO DATA(assignment) WHERE ItemUUID  = item-ItemUUID
                                                    AND %is_draft = item-%is_draft.
          CASE assignment-AssignmentStatus.
            WHEN zif_asset_loan_const=>assignment_status-assigned.
              assigned += 1.
            WHEN zif_asset_loan_const=>assignment_status-checked_out.
              assigned += 1.
              open     += 1.
            WHEN zif_asset_loan_const=>assignment_status-returned
              OR zif_asset_loan_const=>assignment_status-lost.
              assigned += 1.
              closed   += 1.
          ENDCASE.
        ENDLOOP.

        DATA(new_item_status) = COND zrap_asset_req_i-item_status(
          WHEN item-ApprovedQuantity <= 0                THEN zif_asset_loan_const=>item_status-not_approved
          WHEN closed > 0 AND closed = assigned          THEN zif_asset_loan_const=>item_status-closed
          WHEN open > 0                                  THEN zif_asset_loan_const=>item_status-checked_out
          WHEN assigned >= item-ApprovedQuantity         THEN zif_asset_loan_const=>item_status-assigned
          ELSE                                                zif_asset_loan_const=>item_status-approved ).

        IF new_item_status <> item-ItemStatus.
          APPEND VALUE #( %tky = item-%tky ItemStatus = new_item_status ) TO item_updates.
        ENDIF.

        IF item-ApprovedQuantity > 0.
          total_needed   += item-ApprovedQuantity.
          total_assigned += assigned.
        ENDIF.
        total_open   += open.
        total_closed += closed.
      ENDLOOP.

      DATA(new_status) = request-Status.
      DATA(completion) = request-CompletionDate.

      CASE request-Status.
        WHEN zif_asset_loan_const=>request_status-approved
          OR zif_asset_loan_const=>request_status-asset_assigned.
          new_status = COND #( WHEN total_needed > 0 AND total_assigned >= total_needed
                               THEN zif_asset_loan_const=>request_status-asset_assigned
                               ELSE zif_asset_loan_const=>request_status-approved ).
        WHEN zif_asset_loan_const=>request_status-checked_out
          OR zif_asset_loan_const=>request_status-partially_returned.
          IF total_open = 0.
            new_status = zif_asset_loan_const=>request_status-completed.
            completion = today.
          ELSEIF total_closed > 0.
            new_status = zif_asset_loan_const=>request_status-partially_returned.
          ELSE.
            new_status = zif_asset_loan_const=>request_status-checked_out.
          ENDIF.
      ENDCASE.

      IF new_status <> request-Status OR completion <> request-CompletionDate.
        APPEND VALUE #( %tky = request-%tky Status = new_status CompletionDate = completion ) TO request_updates.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request UPDATE FIELDS ( Status CompletionDate ) WITH request_updates
      ENTITY Item    UPDATE FIELDS ( ItemStatus )            WITH item_updates.
  ENDMETHOD.

ENDCLASS.


"=====================================================================
" ROOT: Request
"=====================================================================
CLASS lhc_request DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Request RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Request RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Request RESULT result.

    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Request~setDefaultValues.

    METHODS determineApprover FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Request~determineApprover.

    METHODS setRequestId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Request~setRequestId.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Request~validateDates.

    METHODS validateHeader FOR VALIDATE ON SAVE
      IMPORTING keys FOR Request~validateHeader.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION Request~Submit RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION Request~Approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION Request~Reject RESULT result.

    METHODS returnForCorrection FOR MODIFY
      IMPORTING keys FOR ACTION Request~ReturnForCorrection RESULT result.

    METHODS checkout FOR MODIFY
      IMPORTING keys FOR ACTION Request~Checkout RESULT result.

    METHODS cancel FOR MODIFY
      IMPORTING keys FOR ACTION Request~Cancel RESULT result.
ENDCLASS.

CLASS lhc_request IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Trial: everybody may create requests.
    " Real system: AUTHORITY-CHECK on an own authorization object here.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_authorizations.
    " BR-012: only the determined approver may Approve / Reject / Return.
    " Only the requester may change, delete or submit the request.
    DATA(user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( RequesterID ApproverID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      FAILED failed.

    LOOP AT requests INTO DATA(request).
      DATA(requester_auth) = COND #( WHEN request-RequesterID = user OR request-RequesterID IS INITIAL
                                     THEN if_abap_behv=>auth-allowed
                                     ELSE if_abap_behv=>auth-unauthorized ).
      DATA(approver_auth)  = COND #( WHEN request-ApproverID = user
                                     THEN if_abap_behv=>auth-allowed
                                     ELSE if_abap_behv=>auth-unauthorized ).

      APPEND VALUE #( %tky                        = request-%tky
                      %update                     = requester_auth
                      %delete                     = requester_auth
                      %assoc-_Items               = requester_auth
                      %action-Edit                = requester_auth
                      %action-Submit              = requester_auth
                      %action-Approve             = approver_auth
                      %action-Reject              = approver_auth
                      %action-ReturnForCorrection = approver_auth ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_instance_features.
    " sheet 03_Status_Flow / 08_Actions column "Feature Control"
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      FAILED failed.

    LOOP AT requests INTO DATA(request).
      DATA(status)    = request-Status.
      DATA(is_active) = xsdbool( request-%is_draft = if_abap_behv=>mk-off ).
      DATA(editable)  = xsdbool( status IS INITIAL
                              OR status = zif_asset_loan_const=>request_status-draft
                              OR status = zif_asset_loan_const=>request_status-in_correction ).

      APPEND VALUE #(
        %tky          = request-%tky
        %update       = COND #( WHEN editable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %delete       = COND #( WHEN status IS INITIAL OR status = zif_asset_loan_const=>request_status-draft
                                THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %assoc-_Items = COND #( WHEN editable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Edit  = COND #( WHEN editable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        " Business actions only on the saved (active) instance
        %action-Submit = COND #( WHEN is_active = abap_true AND editable = abap_true AND status IS NOT INITIAL
                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Approve = COND #( WHEN is_active = abap_true AND status = zif_asset_loan_const=>request_status-submitted
                                  THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Reject = COND #( WHEN is_active = abap_true AND status = zif_asset_loan_const=>request_status-submitted
                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-ReturnForCorrection = COND #( WHEN is_active = abap_true AND status = zif_asset_loan_const=>request_status-submitted
                                              THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Checkout = COND #( WHEN is_active = abap_true AND status = zif_asset_loan_const=>request_status-asset_assigned
                                   THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Cancel = COND #( WHEN is_active = abap_true
                                  AND ( status = zif_asset_loan_const=>request_status-draft
                                     OR status = zif_asset_loan_const=>request_status-submitted
                                     OR status = zif_asset_loan_const=>request_status-approved
                                     OR status = zif_asset_loan_const=>request_status-asset_assigned )
                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD setDefaultValues.
    " DET-001
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( RequesterID RequestDate Status DepartmentID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests).

    DATA(user)  = cl_abap_context_info=>get_user_technical_name( ).
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    SELECT SINGLE FROM zrap_user_dept
           FIELDS department_id
           WHERE user_id   = @user
             AND is_active = @abap_true
           INTO @DATA(default_department).

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( RequesterID RequestDate Status DepartmentID )
        WITH VALUE #( FOR r IN requests (
               %tky         = r-%tky
               RequesterID  = COND #( WHEN r-RequesterID  IS INITIAL THEN user  ELSE r-RequesterID )
               RequestDate  = COND #( WHEN r-RequestDate  IS INITIAL THEN today ELSE r-RequestDate )
               Status       = COND #( WHEN r-Status       IS INITIAL THEN zif_asset_loan_const=>request_status-draft ELSE r-Status )
               DepartmentID = COND #( WHEN r-DepartmentID IS INITIAL THEN default_department ELSE r-DepartmentID ) ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.


  METHOD determineApprover.
    " DET-003 (header side: department changed)
    lcl_helper=>determine_approver( CORRESPONDING #( keys ) ).
  ENDMETHOD.


  METHOD setRequestId.
    " Business request ID = last ID + 1 (10 digits).
    " Simple solution for the OJT project; a productive app would use a number range object.
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( RequestID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests).

    DELETE requests WHERE RequestID IS NOT INITIAL.
    CHECK requests IS NOT INITIAL.

    SELECT SINGLE FROM zrap_asset_req_h
           FIELDS MAX( request_id )
           INTO @DATA(max_id).

    DATA(last_number) = CONV i( max_id ).

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( RequestID )
        WITH VALUE #( FOR r IN requests INDEX INTO idx (
               %tky      = r-%tky
               RequestID = |{ last_number + idx WIDTH = 10 ALIGN = RIGHT PAD = '0' }| ) ).
  ENDMETHOD.


  METHOD validateDates.
    " BR-003
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( NeededFromDate ExpectedReturnDate ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests).

    LOOP AT requests INTO DATA(request).
      " clear old messages of this validation (draft keeps messages)
      APPEND VALUE #( %tky = request-%tky %state_area = 'VALIDATE_DATES' ) TO reported-request.

      IF request-NeededFromDate IS NOT INITIAL
     AND request-ExpectedReturnDate IS NOT INITIAL
     AND request-ExpectedReturnDate < request-NeededFromDate.
        APPEND VALUE #( %tky = request-%tky ) TO failed-request.
        APPEND VALUE #( %tky        = request-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Expected return date is invalid' )
                        %element-ExpectedReturnDate = if_abap_behv=>mk-on ) TO reported-request.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validateHeader.
    " Mandatory fields + department/location must exist and be active
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( DepartmentID LocationID NeededFromDate ExpectedReturnDate Purpose ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests).

    LOOP AT requests INTO DATA(request).
      APPEND VALUE #( %tky = request-%tky %state_area = 'VALIDATE_HEADER' ) TO reported-request.

      DATA(error_text) = ``.
      IF request-DepartmentID IS INITIAL OR request-LocationID IS INITIAL
      OR request-NeededFromDate IS INITIAL OR request-ExpectedReturnDate IS INITIAL
      OR request-Purpose IS INITIAL.
        error_text = 'Fill in department, location, dates and purpose'.
      ELSE.
        SELECT SINGLE FROM zrap_department FIELDS @abap_true
               WHERE department_id = @request-DepartmentID AND is_active = @abap_true
               INTO @DATA(department_ok).
        SELECT SINGLE FROM zrap_location FIELDS @abap_true
               WHERE location_id = @request-LocationID AND is_active = @abap_true
               INTO @DATA(location_ok).
        IF department_ok = abap_false.
          error_text = |Department { request-DepartmentID } does not exist or is inactive|.
        ELSEIF location_ok = abap_false.
          error_text = |Location { request-LocationID } does not exist or is inactive|.
        ENDIF.
        CLEAR: department_ok, location_ok.
      ENDIF.

      IF error_text IS NOT INITIAL.
        APPEND VALUE #( %tky = request-%tky ) TO failed-request.
        APPEND VALUE #( %tky        = request-%tky
                        %state_area = 'VALIDATE_HEADER'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = error_text ) ) TO reported-request.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD submit.
    " ACT-001: BR-001, BR-003, BR-004, approver must be found
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( NeededFromDate ExpectedReturnDate ApproverID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      ENTITY Request BY \_Items
        FIELDS ( RequestUUID CategoryID RequestedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Request.

    LOOP AT requests INTO DATA(request).
      DATA messages TYPE string_table.
      CLEAR messages.

      " BR-001
      IF NOT line_exists( items[ RequestUUID = request-RequestUUID ] ).
        APPEND `Please add at least one requested asset item` TO messages.
      ENDIF.

      " BR-003
      IF request-ExpectedReturnDate < request-NeededFromDate.
        APPEND `Expected return date is invalid` TO messages.
      ENDIF.

      " BR-004
      DATA duration TYPE i.
      duration = request-ExpectedReturnDate - request-NeededFromDate.
      LOOP AT items INTO DATA(item) WHERE RequestUUID = request-RequestUUID.
        IF item-RequestedQuantity <= 0.
          APPEND |Item { item-CategoryID }: requested quantity must be greater than zero| TO messages.
        ENDIF.
        SELECT SINGLE FROM zrap_asset_cat FIELDS max_loan_days
               WHERE category_id = @item-CategoryID
               INTO @DATA(max_days).
        IF sy-subrc = 0 AND duration > max_days.
          APPEND |Loan duration exceeds maximum for category { item-CategoryID } ({ max_days } days)| TO messages.
        ENDIF.
      ENDLOOP.

      " Approver must be determined (DET-003)
      IF request-ApproverID IS INITIAL.
        APPEND `No approver configured for this department/category` TO messages.
      ENDIF.

      IF messages IS INITIAL.
        APPEND VALUE #( %tky = request-%tky Status = zif_asset_loan_const=>request_status-submitted ) TO updates.
      ELSE.
        APPEND VALUE #( %tky = request-%tky ) TO failed-request.
        LOOP AT messages INTO DATA(text).
          APPEND VALUE #( %tky = request-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = text ) ) TO reported-request.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request UPDATE FIELDS ( Status ) WITH updates.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( updates )
      RESULT DATA(result_requests).
    result = VALUE #( FOR r IN result_requests ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD approve.
    " ACT-002: approver check is done in get_instance_authorizations (BR-012).
    " Approved quantity is initialised with the requested quantity;
    " the asset manager can reduce it with SetApprovedQuantity.
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request BY \_Items
        FIELDS ( RequestedQuantity ApprovedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR k IN keys ( %tky = k-%tky Status = zif_asset_loan_const=>request_status-approved ) )
      ENTITY Item
        UPDATE FIELDS ( ApprovedQuantity )
        WITH VALUE #( FOR i IN items WHERE ( ApprovedQuantity = 0 )
                      ( %tky = i-%tky ApprovedQuantity = i-RequestedQuantity ) ).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).
    result = VALUE #( FOR r IN requests ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD reject.
    " ACT-003: reason mandatory
    DATA(valid_keys) = keys.
    LOOP AT keys INTO DATA(key) WHERE %param-Reason IS INITIAL.
      APPEND VALUE #( %tky = key-%tky ) TO failed-request.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                    text     = 'Rejection reason is mandatory' ) ) TO reported-request.
    ENDLOOP.
    DELETE valid_keys WHERE %param-Reason IS INITIAL.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status RejectionReason )
        WITH VALUE #( FOR k IN valid_keys ( %tky            = k-%tky
                                            Status          = zif_asset_loan_const=>request_status-rejected
                                            RejectionReason = k-%param-Reason ) ).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( valid_keys )
      RESULT DATA(requests).
    result = VALUE #( FOR r IN requests ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD returnForCorrection.
    " ACT-004: reason mandatory
    DATA(valid_keys) = keys.
    LOOP AT keys INTO DATA(key) WHERE %param-Reason IS INITIAL.
      APPEND VALUE #( %tky = key-%tky ) TO failed-request.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                    text     = 'Correction reason is mandatory' ) ) TO reported-request.
    ENDLOOP.
    DELETE valid_keys WHERE %param-Reason IS INITIAL.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status CorrectionReason )
        WITH VALUE #( FOR k IN valid_keys ( %tky             = k-%tky
                                            Status           = zif_asset_loan_const=>request_status-in_correction
                                            CorrectionReason = k-%param-Reason ) ).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( valid_keys )
      RESULT DATA(requests).
    result = VALUE #( FOR r IN requests ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD checkout.
    " ACT-007 / BR-009: every approved quantity must be fully assigned
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request BY \_Items
        FIELDS ( RequestUUID ApprovedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item BY \_Assignments
        FIELDS ( ItemUUID AssignmentStatus ) WITH CORRESPONDING #( items )
        RESULT DATA(assignments).

    DATA request_updates    TYPE TABLE FOR UPDATE zi_asset_loan_request\\Request.
    DATA assignment_updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Assignment.

    LOOP AT keys INTO DATA(key).
      DATA(complete) = abap_true.
      LOOP AT items INTO DATA(item) WHERE RequestUUID = key-RequestUUID AND ApprovedQuantity > 0.
        DATA(assigned) = REDUCE i( INIT n = 0
                                   FOR a IN assignments
                                   WHERE ( ItemUUID = item-ItemUUID
                                       AND AssignmentStatus = zif_asset_loan_const=>assignment_status-assigned )
                                   NEXT n = n + 1 ).
        IF assigned <> item-ApprovedQuantity.
          complete = abap_false.
        ENDIF.
      ENDLOOP.

      IF complete = abap_false.
        APPEND VALUE #( %tky = key-%tky ) TO failed-request.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Assign all approved assets before checkout' ) ) TO reported-request.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky         = key-%tky
                      Status       = zif_asset_loan_const=>request_status-checked_out
                      CheckoutDate = today ) TO request_updates.

      LOOP AT items INTO item WHERE RequestUUID = key-RequestUUID.
        LOOP AT assignments INTO DATA(assignment)
             WHERE ItemUUID = item-ItemUUID
               AND AssignmentStatus = zif_asset_loan_const=>assignment_status-assigned.
          APPEND VALUE #( %tky             = assignment-%tky
                          AssignmentStatus = zif_asset_loan_const=>assignment_status-checked_out
                          CheckoutDate     = today ) TO assignment_updates.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request    UPDATE FIELDS ( Status CheckoutDate )           WITH request_updates
      ENTITY Assignment UPDATE FIELDS ( AssignmentStatus CheckoutDate ) WITH assignment_updates.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( request_updates )
      RESULT DATA(requests).
    result = VALUE #( FOR r IN requests ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD cancel.
    " ACT-010: reason mandatory, nothing checked out, release reserved assets.
    " The header table has no CANCEL_REASON field, so the reason is stored
    " in REJECTION_REASON (add an own field if your reviewer prefers).
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request BY \_Items
        FIELDS ( RequestUUID ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item BY \_Assignments
        FIELDS ( ItemUUID AssignmentStatus ) WITH CORRESPONDING #( items )
        RESULT DATA(assignments).

    DATA request_updates    TYPE TABLE FOR UPDATE zi_asset_loan_request\\Request.
    DATA item_updates       TYPE TABLE FOR UPDATE zi_asset_loan_request\\Item.
    DATA assignment_updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Assignment.

    LOOP AT keys INTO DATA(key).
      IF key-%param-Reason IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-request.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Cancellation reason is mandatory' ) ) TO reported-request.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = key-%tky
                      Status          = zif_asset_loan_const=>request_status-cancelled
                      RejectionReason = key-%param-Reason ) TO request_updates.

      LOOP AT items INTO DATA(item) WHERE RequestUUID = key-RequestUUID.
        APPEND VALUE #( %tky = item-%tky ItemStatus = zif_asset_loan_const=>item_status-not_approved ) TO item_updates.
        LOOP AT assignments INTO DATA(assignment)
             WHERE ItemUUID = item-ItemUUID
               AND AssignmentStatus = zif_asset_loan_const=>assignment_status-assigned.
          " saver sets the asset back to Available
          APPEND VALUE #( %tky             = assignment-%tky
                          AssignmentStatus = zif_asset_loan_const=>assignment_status-cancelled ) TO assignment_updates.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request    UPDATE FIELDS ( Status RejectionReason ) WITH request_updates
      ENTITY Item       UPDATE FIELDS ( ItemStatus )             WITH item_updates
      ENTITY Assignment UPDATE FIELDS ( AssignmentStatus )       WITH assignment_updates.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( request_updates )
      RESULT DATA(requests).
    result = VALUE #( FOR r IN requests ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.


"=====================================================================
" CHILD: Item
"=====================================================================
CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    METHODS setItemNumber FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setItemNumber.

    METHODS determineApproverFromItem FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~determineApproverFromItem.

    METHODS recalcOnQuantity FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~recalcOnQuantity.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateQuantity.

    METHODS validateCategory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateCategory.

    METHODS setApprovedQuantity FOR MODIFY
      IMPORTING keys FOR ACTION Item~SetApprovedQuantity RESULT result.

    METHODS assignAsset FOR MODIFY
      IMPORTING keys FOR ACTION Item~AssignAsset RESULT result.

ENDCLASS.

CLASS lhc_item IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item
        FIELDS ( RequestUUID ApprovedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items)
      ENTITY Item BY \_Request
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      ENTITY Item BY \_Assignments
        FIELDS ( ItemUUID AssignmentStatus ) WITH CORRESPONDING #( keys )
        RESULT DATA(assignments).

    LOOP AT items INTO DATA(item).
      DATA(status) = VALUE #( requests[ RequestUUID = item-RequestUUID
                                        %is_draft   = item-%is_draft ]-Status OPTIONAL ).
      DATA(is_active) = xsdbool( item-%is_draft = if_abap_behv=>mk-off ).
      DATA(assigned) = REDUCE i( INIT n = 0
                                 FOR a IN assignments
                                 WHERE ( ItemUUID = item-ItemUUID
                                     AND AssignmentStatus <> zif_asset_loan_const=>assignment_status-cancelled )
                                 NEXT n = n + 1 ).

      APPEND VALUE #(
        %tky = item-%tky
        %action-SetApprovedQuantity = COND #( WHEN is_active = abap_true
                                               AND status = zif_asset_loan_const=>request_status-approved
                                              THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        " hidden/disabled when assigned count reaches approved quantity
        %action-AssignAsset = COND #( WHEN is_active = abap_true
                                       AND status = zif_asset_loan_const=>request_status-approved
                                       AND assigned < item-ApprovedQuantity
                                      THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD setItemNumber.
    " DET-002: max item number in transactional buffer + 1
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item BY \_Request
        FIELDS ( RequestUUID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests).

    DATA updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Item.

    LOOP AT requests INTO DATA(request).
      READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
        ENTITY Request BY \_Items
          FIELDS ( ItemNumber ) WITH VALUE #( ( %tky = request-%tky ) )
          RESULT DATA(siblings).

      DATA(max_number) = REDUCE i( INIT m = 0
                                   FOR s IN siblings
                                   NEXT m = COND #( WHEN s-ItemNumber > m THEN s-ItemNumber ELSE m ) ).

      LOOP AT siblings INTO DATA(sibling) WHERE ItemNumber IS INITIAL.
        max_number += 1.
        IF max_number > 999.
          APPEND VALUE #( %tky = sibling-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = 'Maximum of 999 items reached' ) ) TO reported-item.
          EXIT.
        ENDIF.
        APPEND VALUE #( %tky       = sibling-%tky
                        ItemNumber = max_number
                        ItemStatus = zif_asset_loan_const=>item_status-new ) TO updates.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item UPDATE FIELDS ( ItemNumber ItemStatus ) WITH updates.
  ENDMETHOD.


  METHOD determineApproverFromItem.
    " DET-003 (item side: category changed / item created)
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item FIELDS ( RequestUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).
    DATA request_keys TYPE lcl_helper=>tt_request_keys.
    request_keys = VALUE #( FOR i IN items ( %is_draft = i-%is_draft RequestUUID = i-RequestUUID ) ).
    SORT request_keys BY %is_draft RequestUUID.
    DELETE ADJACENT DUPLICATES FROM request_keys COMPARING %is_draft RequestUUID.
    lcl_helper=>determine_approver( request_keys ).
  ENDMETHOD.


  METHOD recalcOnQuantity.
    " DET-004 (approved quantity changed)
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item FIELDS ( RequestUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).
    DATA request_keys TYPE lcl_helper=>tt_request_keys.
    request_keys = VALUE #( FOR i IN items ( %is_draft = i-%is_draft RequestUUID = i-RequestUUID ) ).
    SORT request_keys BY %is_draft RequestUUID.
    DELETE ADJACENT DUPLICATES FROM request_keys COMPARING %is_draft RequestUUID.
    lcl_helper=>recalc_status( request_keys ).
  ENDMETHOD.


  METHOD validateQuantity.
    " BR-002
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item
        FIELDS ( RequestUUID RequestedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'VALIDATE_QUANTITY'
                      %path       = VALUE #( request-%is_draft   = item-%is_draft
                                             request-RequestUUID = item-RequestUUID ) ) TO reported-item.

      IF item-RequestedQuantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky        = item-%tky
                        %state_area = 'VALIDATE_QUANTITY'
                        %path       = VALUE #( request-%is_draft   = item-%is_draft
                                               request-RequestUUID = item-RequestUUID )
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = 'Requested quantity must be greater than zero' )
                        %element-RequestedQuantity = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validateCategory.
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item
        FIELDS ( RequestUUID CategoryID ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'VALIDATE_CATEGORY'
                      %path       = VALUE #( request-%is_draft   = item-%is_draft
                                             request-RequestUUID = item-RequestUUID ) ) TO reported-item.

      SELECT SINGLE FROM zrap_asset_cat FIELDS @abap_true
             WHERE category_id = @item-CategoryID AND is_active = @abap_true
             INTO @DATA(category_ok).

      IF category_ok = abap_false.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky        = item-%tky
                        %state_area = 'VALIDATE_CATEGORY'
                        %path       = VALUE #( request-%is_draft   = item-%is_draft
                                               request-RequestUUID = item-RequestUUID )
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = |Category { item-CategoryID } is invalid| )
                        %element-CategoryID = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
      CLEAR category_ok.
    ENDLOOP.
  ENDMETHOD.


  METHOD setApprovedQuantity.
    " ACT-005 / BR-005: 0 <= approved <= requested
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item
        FIELDS ( RequestedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Item.

    LOOP AT keys INTO DATA(key).
      DATA(item) = VALUE #( items[ KEY id %tky = key-%tky ] OPTIONAL ).
      IF key-%param-ApprovedQuantity < 0 OR key-%param-ApprovedQuantity > item-RequestedQuantity.
        APPEND VALUE #( %tky = key-%tky ) TO failed-item.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Approved quantity exceeds requested quantity' ) ) TO reported-item.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = key-%tky ApprovedQuantity = key-%param-ApprovedQuantity ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item UPDATE FIELDS ( ApprovedQuantity ) WITH updates.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( updates )
      RESULT DATA(result_items).
    result = VALUE #( FOR i IN result_items ( %tky = i-%tky %param = i ) ).
  ENDMETHOD.


  METHOD assignAsset.
    " ACT-006: BR-006, BR-007, BR-008 + category/location must match
    DATA(user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA now TYPE timestampl.
    GET TIME STAMP FIELD now.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item
        FIELDS ( RequestUUID CategoryID ApprovedQuantity ) WITH CORRESPONDING #( keys )
        RESULT DATA(items)
      ENTITY Item BY \_Request
        FIELDS ( LocationID ) WITH CORRESPONDING #( keys )
        RESULT DATA(requests)
      ENTITY Item BY \_Assignments
        FIELDS ( ItemUUID AssetUUID AssignmentStatus ) WITH CORRESPONDING #( keys )
        RESULT DATA(existing).

    DATA creates TYPE TABLE FOR CREATE zi_asset_loan_request\\Item\_Assignments.
    DATA in_db    TYPE abap_bool.
    DATA in_draft TYPE abap_bool.
    DATA counter  TYPE i.
    DATA new_assets TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    LOOP AT keys INTO DATA(key).
      DATA(item) = VALUE #( items[ KEY id %tky = key-%tky ] OPTIONAL ).
      DATA(request) = VALUE #( requests[ RequestUUID = item-RequestUUID %is_draft = item-%is_draft ] OPTIONAL ).
      DATA(error_text) = ``.

      SELECT SINGLE FROM zrap_asset_mst
             FIELDS asset_uuid, category_id, location_id, asset_status, is_active
             WHERE asset_id = @key-%param-AssetID
             INTO @DATA(asset).

      IF sy-subrc <> 0.
        error_text = |Asset { key-%param-AssetID } does not exist|.
      ELSEIF asset-is_active <> abap_true
          OR asset-asset_status <> zif_asset_loan_const=>asset_status-available.
        error_text = 'Selected asset is not available'.                          " BR-006
      ELSEIF asset-category_id <> item-CategoryID.
        error_text = 'Asset category does not match the requested category'.
      ELSEIF asset-location_id <> request-LocationID.
        error_text = 'Asset location does not match the delivery location'.
      ELSE.
        " BR-007: no open assignment for this asset (DB, drafts, current buffer)
        CLEAR: in_db, in_draft.
        SELECT SINGLE FROM zrap_asset_asgn FIELDS @abap_true
               WHERE asset_uuid = @asset-asset_uuid
                 AND ( assignment_status = @zif_asset_loan_const=>assignment_status-assigned
                    OR assignment_status = @zif_asset_loan_const=>assignment_status-checked_out )
               INTO @in_db.
        SELECT SINGLE FROM zrap_asset_rad FIELDS @abap_true
               WHERE assetuuid = @asset-asset_uuid
                 AND ( assignmentstatus = @zif_asset_loan_const=>assignment_status-assigned
                    OR assignmentstatus = @zif_asset_loan_const=>assignment_status-checked_out )
               INTO @in_draft.
        IF in_db = abap_true OR in_draft = abap_true
        OR line_exists( existing[ AssetUUID = asset-asset_uuid ] )
        OR line_exists( new_assets[ table_line = asset-asset_uuid ] ).
          error_text = 'Asset is already assigned to another request'.
        ELSE.
          " BR-008
          DATA(assigned) = REDUCE i( INIT n = 0
                                     FOR a IN existing
                                     WHERE ( ItemUUID = item-ItemUUID
                                         AND AssignmentStatus <> zif_asset_loan_const=>assignment_status-cancelled )
                                     NEXT n = n + 1 ).
          IF assigned >= item-ApprovedQuantity.
            error_text = 'Assigned quantity exceeds approved quantity'.
          ENDIF.
        ENDIF.
      ENDIF.

      IF error_text IS NOT INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-item.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = error_text ) ) TO reported-item.
        CONTINUE.
      ENDIF.

      counter += 1.
      APPEND asset-asset_uuid TO new_assets.
      APPEND VALUE #( %tky    = item-%tky
                      %target = VALUE #( ( %cid             = |ASSIGN_{ counter }|
                                           %is_draft        = item-%is_draft
                                           RequestUUID      = item-RequestUUID
                                           AssetUUID        = asset-asset_uuid
                                           AssignedBy       = user
                                           AssignedAt       = now
                                           AssignmentStatus = zif_asset_loan_const=>assignment_status-assigned ) ) )
             TO creates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item
        CREATE BY \_Assignments
        FIELDS ( RequestUUID AssetUUID AssignedBy AssignedAt AssignmentStatus )
        WITH creates
      MAPPED DATA(create_mapped)
      FAILED DATA(create_failed)
      REPORTED DATA(create_reported).

    APPEND LINES OF create_mapped-assignment   TO mapped-assignment.
    APPEND LINES OF create_failed-item         TO failed-item.
    APPEND LINES OF create_reported-assignment TO reported-assignment.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(result_items).
    result = VALUE #( FOR i IN result_items ( %tky = i-%tky %param = i ) ).
  ENDMETHOD.

ENDCLASS.


"=====================================================================
" GRANDCHILD: Assignment
"=====================================================================
CLASS lhc_assignment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Assignment RESULT result.

    METHODS updateRequestStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Assignment~updateRequestStatus.

    METHODS returnAsset FOR MODIFY
      IMPORTING keys FOR ACTION Assignment~ReturnAsset RESULT result.

    METHODS reportLost FOR MODIFY
      IMPORTING keys FOR ACTION Assignment~ReportLost RESULT result.
ENDCLASS.

CLASS lhc_assignment IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Assignment
        FIELDS ( AssignmentStatus ) WITH CORRESPONDING #( keys )
        RESULT DATA(assignments)
      FAILED failed.

    result = VALUE #( FOR a IN assignments
      ( %tky = a-%tky
        %action-ReturnAsset = COND #( WHEN a-%is_draft = if_abap_behv=>mk-off
                                       AND a-AssignmentStatus = zif_asset_loan_const=>assignment_status-checked_out
                                      THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-ReportLost  = COND #( WHEN a-%is_draft = if_abap_behv=>mk-off
                                       AND a-AssignmentStatus = zif_asset_loan_const=>assignment_status-checked_out
                                      THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.


  METHOD updateRequestStatus.
    " DET-004 (assignment created / status changed)
    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Assignment FIELDS ( RequestUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(assignments).

    DATA request_keys TYPE lcl_helper=>tt_request_keys.
    request_keys = VALUE #( FOR a IN assignments ( %is_draft = a-%is_draft RequestUUID = a-RequestUUID ) ).
    SORT request_keys BY %is_draft RequestUUID.
    DELETE ADJACENT DUPLICATES FROM request_keys COMPARING %is_draft RequestUUID.

    lcl_helper=>recalc_status( request_keys ).
  ENDMETHOD.


  METHOD returnAsset.
    " ACT-008 / BR-010: date and condition mandatory
    DATA updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Assignment.

    LOOP AT keys INTO DATA(key).
      IF key-%param-ReturnDate IS INITIAL OR key-%param-ReturnCondition IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-assignment.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Return date and condition are required' ) ) TO reported-assignment.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky             = key-%tky
                      ReturnDate       = key-%param-ReturnDate
                      ReturnCondition  = key-%param-ReturnCondition
                      ReturnNote       = key-%param-ReturnNote
                      AssignmentStatus = COND #( WHEN key-%param-ReturnCondition = zif_asset_loan_const=>condition-lost
                                                 THEN zif_asset_loan_const=>assignment_status-lost
                                                 ELSE zif_asset_loan_const=>assignment_status-returned ) ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Assignment
        UPDATE FIELDS ( ReturnDate ReturnCondition ReturnNote AssignmentStatus ) WITH updates.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Assignment ALL FIELDS WITH CORRESPONDING #( updates )
      RESULT DATA(assignments).
    result = VALUE #( FOR a IN assignments ( %tky = a-%tky %param = a ) ).
  ENDMETHOD.


  METHOD reportLost.
    " ACT-009
    DATA updates TYPE TABLE FOR UPDATE zi_asset_loan_request\\Assignment.

    LOOP AT keys INTO DATA(key).
      IF key-%param-LostDate IS INITIAL OR key-%param-Note IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-assignment.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Lost date and note are required' ) ) TO reported-assignment.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky             = key-%tky
                      ReturnDate       = key-%param-LostDate
                      ReturnNote       = key-%param-Note
                      ReturnCondition  = zif_asset_loan_const=>condition-lost
                      AssignmentStatus = zif_asset_loan_const=>assignment_status-lost ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Assignment
        UPDATE FIELDS ( ReturnDate ReturnNote ReturnCondition AssignmentStatus ) WITH updates.

    READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
      ENTITY Assignment ALL FIELDS WITH CORRESPONDING #( updates )
      RESULT DATA(assignments).
    result = VALUE #( FOR a IN assignments ( %tky = a-%tky %param = a ) ).
  ENDMETHOD.

ENDCLASS.


"=====================================================================
" SAVER: DET-005 - keep asset master status in sync
" (asset master is not part of this BO, so it is written in the save phase)
"=====================================================================
CLASS lsc_zi_asset_loan_request DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zi_asset_loan_request IMPLEMENTATION.

  METHOD save_modified.
    " New assignment => asset Reserved
    LOOP AT create-assignment INTO DATA(new_assignment).
      UPDATE zrap_asset_mst
         SET asset_status = @zif_asset_loan_const=>asset_status-reserved
       WHERE asset_uuid = @new_assignment-AssetUUID.
    ENDLOOP.

    " Assignment status changed => follow-up asset status
    LOOP AT update-assignment INTO DATA(changed) WHERE %control-AssignmentStatus = if_abap_behv=>mk-on.
      DATA(asset_uuid) = changed-AssetUUID.
      IF asset_uuid IS INITIAL.
        " created in the same transaction?
        asset_uuid = VALUE #( create-assignment[ AssignmentUUID = changed-AssignmentUUID ]-AssetUUID OPTIONAL ).
      ENDIF.
      IF asset_uuid IS INITIAL.
        SELECT SINGLE FROM zrap_asset_asgn FIELDS asset_uuid
               WHERE assignment_uuid = @changed-AssignmentUUID
               INTO @asset_uuid.
      ENDIF.
      CHECK asset_uuid IS NOT INITIAL.

      CASE changed-AssignmentStatus.
        WHEN zif_asset_loan_const=>assignment_status-checked_out.
          UPDATE zrap_asset_mst
             SET asset_status = @zif_asset_loan_const=>asset_status-on_loan
           WHERE asset_uuid = @asset_uuid.

        WHEN zif_asset_loan_const=>assignment_status-returned.
          " BR-011: Good => Available, otherwise (Damaged / Missing accessories) => Maintenance
          DATA(new_status) = COND zrap_asset_mst-asset_status(
                               WHEN changed-ReturnCondition = zif_asset_loan_const=>condition-good
                               THEN zif_asset_loan_const=>asset_status-available
                               ELSE zif_asset_loan_const=>asset_status-maintenance ).
          UPDATE zrap_asset_mst
             SET asset_status   = @new_status,
                 condition_code = @changed-ReturnCondition
           WHERE asset_uuid = @asset_uuid.

        WHEN zif_asset_loan_const=>assignment_status-lost.
          UPDATE zrap_asset_mst
             SET asset_status   = @zif_asset_loan_const=>asset_status-lost,
                 condition_code = @zif_asset_loan_const=>condition-lost
           WHERE asset_uuid = @asset_uuid.

        WHEN zif_asset_loan_const=>assignment_status-cancelled.
          UPDATE zrap_asset_mst
             SET asset_status = @zif_asset_loan_const=>asset_status-available
           WHERE asset_uuid = @asset_uuid.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
