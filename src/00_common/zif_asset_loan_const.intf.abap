INTERFACE zif_asset_loan_const PUBLIC.

  " Request status (table field ZRAP_ASSET_REQ_H-STATUS) - sheet 03_Status_Flow
  CONSTANTS:
    BEGIN OF request_status,
      draft              TYPE c LENGTH 2 VALUE '01',
      submitted          TYPE c LENGTH 2 VALUE '02',
      approved           TYPE c LENGTH 2 VALUE '03',
      rejected           TYPE c LENGTH 2 VALUE '04',
      in_correction      TYPE c LENGTH 2 VALUE '05',
      asset_assigned     TYPE c LENGTH 2 VALUE '06',
      checked_out        TYPE c LENGTH 2 VALUE '07',
      partially_returned TYPE c LENGTH 2 VALUE '08',
      completed          TYPE c LENGTH 2 VALUE '09',
      cancelled          TYPE c LENGTH 2 VALUE '10',
    END OF request_status.

  " Item status (ZRAP_ASSET_REQ_I-ITEM_STATUS)
  CONSTANTS:
    BEGIN OF item_status,
      new          TYPE c LENGTH 2 VALUE '01',
      approved     TYPE c LENGTH 2 VALUE '02',
      assigned     TYPE c LENGTH 2 VALUE '03',
      checked_out  TYPE c LENGTH 2 VALUE '04',
      closed       TYPE c LENGTH 2 VALUE '05',
      not_approved TYPE c LENGTH 2 VALUE '06',
    END OF item_status.

  " Assignment status (ZRAP_ASSET_ASGN-ASSIGNMENT_STATUS)
  CONSTANTS:
    BEGIN OF assignment_status,
      assigned    TYPE c LENGTH 2 VALUE '01',
      checked_out TYPE c LENGTH 2 VALUE '02',
      returned    TYPE c LENGTH 2 VALUE '03',
      lost        TYPE c LENGTH 2 VALUE '04',
      cancelled   TYPE c LENGTH 2 VALUE '05',
    END OF assignment_status.

  " Asset status (ZRAP_ASSET_MST-ASSET_STATUS)
  CONSTANTS:
    BEGIN OF asset_status,
      available   TYPE c LENGTH 2 VALUE '01',
      reserved    TYPE c LENGTH 2 VALUE '02',
      on_loan     TYPE c LENGTH 2 VALUE '03',
      maintenance TYPE c LENGTH 2 VALUE '04',
      retired     TYPE c LENGTH 2 VALUE '05',
      lost        TYPE c LENGTH 2 VALUE '06',
    END OF asset_status.

  " Return / asset condition (RETURN_CONDITION, CONDITION_CODE)
  CONSTANTS:
    BEGIN OF condition,
      good            TYPE c LENGTH 2 VALUE '01',
      damaged         TYPE c LENGTH 2 VALUE '02',
      missing_access  TYPE c LENGTH 2 VALUE '03',
      lost            TYPE c LENGTH 2 VALUE '04',
    END OF condition.

ENDINTERFACE.
