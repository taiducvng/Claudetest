CLASS zcl_asset_loan_data_gen DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS zcl_asset_loan_data_gen IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Run with F9 in ADT. Deletes ALL data of the app and inserts demo data.
    " The current user becomes department member AND approver,
    " so a single trial user can test the whole request-to-return flow.
    DATA(user) = cl_abap_context_info=>get_user_technical_name( ).

    DATA departments TYPE STANDARD TABLE OF zrap_department WITH EMPTY KEY.
    DATA locations   TYPE STANDARD TABLE OF zrap_location   WITH EMPTY KEY.
    DATA categories  TYPE STANDARD TABLE OF zrap_asset_cat  WITH EMPTY KEY.
    DATA approvers   TYPE STANDARD TABLE OF zrap_asset_appr WITH EMPTY KEY.
    DATA user_depts  TYPE STANDARD TABLE OF zrap_user_dept  WITH EMPTY KEY.
    DATA assets      TYPE STANDARD TABLE OF zrap_asset_mst  WITH EMPTY KEY.

    " 1. Clean up (transactional + master data)
    DELETE FROM zrap_asset_asgn.
    DELETE FROM zrap_asset_req_i.
    DELETE FROM zrap_asset_req_h.
    DELETE FROM zrap_asset_mst.
    DELETE FROM zrap_asset_appr.
    DELETE FROM zrap_user_dept.
    DELETE FROM zrap_asset_cat.
    DELETE FROM zrap_location.
    DELETE FROM zrap_department.

    " 2. Departments
    departments = VALUE #(
      ( department_id = 'IT'    department_name = 'Information Technology' manager_id = user is_active = abap_true )
      ( department_id = 'HR'    department_name = 'Human Resources'        manager_id = user is_active = abap_true )
      ( department_id = 'FIN'   department_name = 'Finance'                manager_id = user is_active = abap_true )
      ( department_id = 'OLD'   department_name = 'Closed Department'      is_active = abap_false ) ).
    INSERT zrap_department FROM TABLE @departments.

    " 3. Locations
    locations = VALUE #(
      ( location_id = 'HCM01' location_name = 'Ho Chi Minh Office' city = 'Ho Chi Minh City' country_code = 'VN' is_active = abap_true )
      ( location_id = 'HAN01' location_name = 'Ha Noi Office'      city = 'Ha Noi'           country_code = 'VN' is_active = abap_true )
      ( location_id = 'DAN01' location_name = 'Da Nang Office'     city = 'Da Nang'          country_code = 'VN' is_active = abap_true ) ).
    INSERT zrap_location FROM TABLE @locations.

    " 4. Categories (priority 1 = highest, used by approver determination)
    categories = VALUE #(
      ( category_id = 'LAPTOP' category_name = 'Laptop'  max_loan_days = 30 approval_required = abap_true priority = 1 is_active = abap_true )
      ( category_id = 'PHONE'  category_name = 'Phone'   max_loan_days = 14 approval_required = abap_true priority = 2 is_active = abap_true )
      ( category_id = 'MONIT'  category_name = 'Monitor' max_loan_days = 60 approval_required = abap_true priority = 3 is_active = abap_true )
      ( category_id = 'TABLET' category_name = 'Tablet'  max_loan_days = 30 approval_required = abap_true priority = 2 is_active = abap_true ) ).
    INSERT zrap_asset_cat FROM TABLE @categories.

    " 5. Approval configuration: every department/category -> current user
    LOOP AT departments INTO DATA(dept) WHERE is_active = abap_true.
      LOOP AT categories INTO DATA(cat).
        APPEND VALUE #( department_id = dept-department_id
                        category_id   = cat-category_id
                        approver_id   = user
                        approver_name = |Approver { user }|
                        is_active     = abap_true ) TO approvers.
      ENDLOOP.
    ENDLOOP.
    INSERT zrap_asset_appr FROM TABLE @approvers.

    " 6. Current user belongs to IT
    user_depts = VALUE #( ( user_id = user department_id = 'IT' is_active = abap_true ) ).
    INSERT zrap_user_dept FROM TABLE @user_depts.

    " 7. Physical assets
    TRY.
        assets = VALUE #(
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'LT-0001' category_id = 'LAPTOP'
            asset_name = 'Laptop Dell Latitude 5440' brand = 'Dell' model = 'Latitude 5440' serial_number = 'SN-LT-0001'
            location_id = 'HCM01' asset_status = '01' condition_code = '01' purchase_date = '20250115' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'LT-0002' category_id = 'LAPTOP'
            asset_name = 'Laptop Lenovo ThinkPad T14' brand = 'Lenovo' model = 'T14 Gen 4' serial_number = 'SN-LT-0002'
            location_id = 'HCM01' asset_status = '01' condition_code = '01' purchase_date = '20250201' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'LT-0003' category_id = 'LAPTOP'
            asset_name = 'Laptop HP EliteBook 840' brand = 'HP' model = 'EliteBook 840 G10' serial_number = 'SN-LT-0003'
            location_id = 'HCM01' asset_status = '01' condition_code = '01' purchase_date = '20250310' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'LT-0004' category_id = 'LAPTOP'
            asset_name = 'Laptop Dell (on loan)' brand = 'Dell' model = 'Latitude 7440' serial_number = 'SN-LT-0004'
            location_id = 'HCM01' asset_status = '03' condition_code = '01' purchase_date = '20240910' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'LT-0005' category_id = 'LAPTOP'
            asset_name = 'Laptop Dell Ha Noi' brand = 'Dell' model = 'Latitude 5440' serial_number = 'SN-LT-0005'
            location_id = 'HAN01' asset_status = '01' condition_code = '01' purchase_date = '20250115' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'MN-0001' category_id = 'MONIT'
            asset_name = 'Monitor Dell 27 inch' brand = 'Dell' model = 'P2723DE' serial_number = 'SN-MN-0001'
            location_id = 'HCM01' asset_status = '01' condition_code = '01' purchase_date = '20240505' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'MN-0002' category_id = 'MONIT'
            asset_name = 'Monitor LG 24 inch' brand = 'LG' model = '24MP400' serial_number = 'SN-MN-0002'
            location_id = 'HCM01' asset_status = '01' condition_code = '01' purchase_date = '20240505' is_active = abap_true )
          ( asset_uuid = cl_system_uuid=>create_uuid_x16_static( ) asset_id = 'PH-0001' category_id = 'PHONE'
            asset_name = 'iPhone 15 test device' brand = 'Apple' model = 'iPhone 15' serial_number = 'SN-PH-0001'
            location_id = 'HCM01' asset_status = '01' condition_code = '01' purchase_date = '20250620' is_active = abap_true ) ).
      CATCH cx_uuid_error INTO DATA(uuid_error).
        out->write( uuid_error->get_text( ) ).
        RETURN.
    ENDTRY.
    INSERT zrap_asset_mst FROM TABLE @assets.

    out->write( |Demo data created. Current user { user } is in department IT and is approver for all categories.| ).
  ENDMETHOD.

ENDCLASS.
