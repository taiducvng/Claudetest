# Hướng dẫn xây dựng app "IT Asset Loan & Return Management" bằng SAP RAP + Fiori Elements

> Dựa trên file thiết kế **DD-RAP-ASSET-001 v1.1** (Excel).
> Môi trường: **SAP BTP ABAP Environment (Trial)**, RAP **Managed + Draft**, **OData V4**, **Fiori Elements** (List Report + Object Page).
> Toàn bộ code mẫu nằm trong thư mục [`src/`](../src). Tài liệu này giải thích **làm gì, ở đâu, theo thứ tự nào, và vì sao**.

---

## Mục lục

0. [Tổng quan: bạn sẽ xây cái gì](#0-tổng-quan)
1. [Chuẩn bị môi trường](#1-chuẩn-bị-môi-trường)
2. [Tạo Domain (giá trị cố định cho status)](#2-tạo-domain)
3. [Tạo 9 bảng dữ liệu](#3-tạo-9-bảng)
4. [Interface hằng số + class tạo dữ liệu mẫu](#4-hằng-số-và-dữ-liệu-mẫu)
5. [CDS master data + Value Help](#5-cds-master-data-và-value-help)
6. [Abstract entity cho tham số action](#6-abstract-entity)
7. [CDS Interface của Business Object (3 tầng)](#7-cds-interface-của-bo)
8. [Behavior Definition + bảng draft](#8-behavior-definition)
9. [Behavior Implementation (logic nghiệp vụ)](#9-behavior-implementation)
10. [Projection layer](#10-projection-layer)
11. [Metadata Extension (giao diện)](#11-metadata-extension)
12. [Service Definition, Service Binding, Preview](#12-service-và-preview)
13. [Kịch bản test end-to-end](#13-test)
14. [Lỗi thường gặp](#14-lỗi-thường-gặp)
15. [Những điểm khác so với Excel và lý do](#15-khác-biệt-so-với-excel)
16. [Mở rộng (tuỳ chọn)](#16-mở-rộng)

---

## 0. Tổng quan

### 0.1 Nghiệp vụ (sheet 02, 03)

```
Employee tạo request (Draft 01)
   └─ thêm item: loại thiết bị + số lượng
Employee Submit ───────────────► Submitted 02
Approver: Approve ─────────────► Approved 03      (approved qty = requested qty)
          Reject (lý do) ──────► Rejected 04
          Return for Correction► In Correction 05 ──(sửa, Submit lại)──► 02
Asset Manager: SetApprovedQuantity / AssignAsset (từng thiết bị vật lý)
   khi đủ số lượng ────────────► Asset Assigned 06
Asset Manager: Checkout ───────► Checked Out 07   (asset: On Loan)
ReturnAsset / ReportLost từng thiết bị
   còn thiết bị chưa trả ──────► Partially Returned 08
   trả hết ────────────────────► Completed 09
Cancel (01/02/03/06) ──────────► Cancelled 10    (giải phóng asset đã reserve)
```

Trạng thái thiết bị (bảng `ZRAP_ASSET_MST`): `01 Available → 02 Reserved → 03 On Loan → 01 Available` (trả Good) hoặc `04 Maintenance` (trả Damaged) hoặc `06 Lost`.

### 0.2 Kiến trúc object (sheet 12)

```
                     ┌──────────────────────── Fiori Elements (Preview) ───────────────────────┐
                     │  Service Binding ZUI_ASSET_LOAN_O4 (OData V4 - UI)                       │
                     │  Service Definition ZUI_ASSET_LOAN                                       │
                     ├──────────────────────────────────────────────────────────────────────────┤
 Projection          │  ZC_ASSET_LOAN_REQUEST ─► ZC_ASSET_LOAN_ITEM ─► ZC_ASSET_ASSIGNMENT      │
                     │  + 3 Metadata Extension (_MDE)  + Projection BDEF                        │
                     ├──────────────────────────────────────────────────────────────────────────┤
 Interface (BO)      │  ZI_ASSET_LOAN_REQUEST ─► ZI_ASSET_LOAN_ITEM ─► ZI_ASSET_ASSIGNMENT      │
                     │  BDEF ZI_ASSET_LOAN_REQUEST  +  class ZBP_I_ASSET_LOAN_REQUEST           │
                     ├──────────────────────────────────────────────────────────────────────────┤
 Master / VH         │  ZI_DEPARTMENT, ZI_LOCATION, ZI_ASSET_CATEGORY, ZI_ASSET_MASTER, ...     │
                     │  ZI_*_VH (value help), ZI_ASSET_LOAN_REQ_CNT (đếm số item/asset)         │
                     ├──────────────────────────────────────────────────────────────────────────┤
 Tables              │  ZRAP_ASSET_REQ_H ─► ZRAP_ASSET_REQ_I ─► ZRAP_ASSET_ASGN (+ 3 bảng draft)│
                     │  ZRAP_ASSET_MST, _CAT, ZRAP_DEPARTMENT, ZRAP_LOCATION, _APPR, ZRAP_USER_DEPT│
                     └──────────────────────────────────────────────────────────────────────────┘
```

### 0.3 Danh sách file trong repo và thứ tự tạo

| Bước | Thư mục | Object |
|---|---|---|
| 2 | (tạo bằng form, không có file) | 5 Domain `ZRAP_D_*` |
| 3 | `src/01_tables` | 9 bảng |
| 4 | `src/00_common` | `ZIF_ASSET_LOAN_CONST`, `ZCL_ASSET_LOAN_DATA_GEN` |
| 5 | `src/02_master_cds` | 4 view master, 1 view approver, 1 view đếm, 10 value help |
| 6 | `src/03_abstract` | 7 abstract entity `ZA_ASSET_*_PARAM` |
| 7 | `src/04_bo_interface` | 3 CDS interface |
| 8–9 | `src/05_behavior` | BDEF + class behavior pool (2 file: global + local types) |
| 10 | `src/06_projection` | 3 CDS projection + projection BDEF |
| 11–12 | `src/07_ui_service` | 3 metadata extension + service definition |

> **Quy tắc vàng:** tạo object theo đúng thứ tự trên. Object sau luôn phụ thuộc object trước — tạo ngược thứ tự sẽ báo lỗi "does not exist".

---

## 1. Chuẩn bị môi trường

1. **Tài khoản BTP Trial** → vào SAP BTP Cockpit → *Boosters* → chạy booster **"Prepare an Account for ABAP Trial"**. Booster tạo instance ABAP và tải về file service key.
2. **Eclipse + ABAP Development Tools (ADT)**: cài Eclipse bản mới nhất, *Help → Install New Software* → `https://tools.hana.ondemand.com/latest` → chọn **ABAP Development Tools**.
3. **Tạo ABAP Cloud Project**: *File → New → Other → ABAP Cloud Project* → *Use a Service Key* → dán service key → đăng nhập trình duyệt.
4. **Tạo package**: chuột phải `ZLOCAL` → *New → ABAP Package*
   - Name: `ZRAP_ASSET_LOAN` (trên Trial, tên package nên có hậu tố riêng nếu dùng chung hệ thống, ví dụ `ZRAP_ASSET_LOAN_TD`)
   - Superpackage: `ZLOCAL`, Software component: `ZLOCAL`, Transport: để trống/local.
5. Thêm package vào **Favorite Packages** để dễ tìm.

> 💡 **Trial dùng chung hệ thống với nhiều người.** Nếu tên object đã tồn tại (ví dụ `ZRAP_ASSET_REQ_H`), hãy thêm hậu tố cá nhân (ví dụ `_TD`) cho **mọi** object và sửa lại tên trong code tương ứng (dùng *Find/Replace* trong Eclipse).

---

## 2. Tạo Domain

Domain dùng để lưu danh sách giá trị cố định + text, sau đó các value help `ZI_*_VH` đọc qua API đã release `DDCDS_CUSTOMER_DOMAIN_VALUE_T`.

Cách tạo: chuột phải package → *New → Other ABAP Repository Object → Dictionary → Domain*. Data type `CHAR`, length `2`. Tab **Fixed Values** nhập các dòng bên dưới. Activate (`Ctrl+F3`).

| Domain | Giá trị |
|---|---|
| `ZRAP_D_REQ_STATUS` | 01 Draft · 02 Submitted · 03 Approved · 04 Rejected · 05 In Correction · 06 Asset Assigned · 07 Checked Out · 08 Partially Returned · 09 Completed · 10 Cancelled |
| `ZRAP_D_ITEM_STATUS` | 01 New · 02 Approved · 03 Assigned · 04 Checked Out · 05 Closed · 06 Not Approved / Cancelled |
| `ZRAP_D_ASGN_STATUS` | 01 Assigned · 02 Checked Out · 03 Returned · 04 Lost · 05 Cancelled |
| `ZRAP_D_ASSET_STATUS` | 01 Available · 02 Reserved · 03 On Loan · 04 Maintenance · 05 Retired · 06 Lost |
| `ZRAP_D_CONDITION` | 01 Good · 02 Damaged · 03 Missing accessories · 04 Lost |

> Text nhập bằng **tiếng Anh** (ngôn ngữ đăng nhập mặc định của Trial). Nếu đăng nhập ngôn ngữ khác mà chưa dịch, cột text sẽ trống.

---

## 3. Tạo 9 bảng

Chuột phải package → *New → Other → Dictionary → Database Table*. Đặt tên, mô tả, *Next → Finish*, rồi **xoá nội dung mặc định và dán** nội dung file tương ứng trong `src/01_tables/`. Activate.

| Bảng | File | Vai trò |
|---|---|---|
| `ZRAP_ASSET_REQ_H` | `zrap_asset_req_h.tabl.ddl` | Header request (root) |
| `ZRAP_ASSET_REQ_I` | `zrap_asset_req_i.tabl.ddl` | Item (con) |
| `ZRAP_ASSET_ASGN` | `zrap_asset_asgn.tabl.ddl` | Thiết bị được gán (cháu) |
| `ZRAP_ASSET_MST` | `zrap_asset_mst.tabl.ddl` | Master thiết bị |
| `ZRAP_ASSET_CAT` | `zrap_asset_cat.tabl.ddl` | Loại thiết bị + số ngày mượn tối đa |
| `ZRAP_DEPARTMENT` | `zrap_department.tabl.ddl` | Phòng ban |
| `ZRAP_LOCATION` | `zrap_location.tabl.ddl` | Địa điểm |
| `ZRAP_ASSET_APPR` | `zrap_asset_appr.tabl.ddl` | Cấu hình người duyệt (phòng ban × loại) |
| `ZRAP_USER_DEPT` | `zrap_user_dept.tabl.ddl` | User thuộc phòng ban nào |

Giải thích nhanh các điểm kỹ thuật:

- **`client : abap.clnt`** là khoá đầu tiên → bảng phụ thuộc client (MAP-017).
- **Khoá kỹ thuật `*_UUID : sysuuid_x16`** → RAP tự sinh UUID (*managed numbering*), không cần number range.
- **Các trường audit** dùng data element chuẩn: `abp_creation_user`, `abp_creation_tstmpl`, `abp_locinst_lastchange_user`, `abp_lastchange_tstmpl`. RAP tự điền khi CDS có annotation `@Semantics...` (bước 7).
- **`local_last_changed_at`** dùng cho ETag/khoá lạc quan (optimistic lock) và *total ETag* của draft.
- **Không cần tạo bảng draft bằng tay** (`ZRAP_ASSET_RHD/RID/RAD`) — sẽ sinh tự động ở bước 8.

> ⚠️ Excel đặt tên `ZRAP_ASSET_ASSIGN` (17 ký tự) nhưng **tên bảng DDIC tối đa 16 ký tự** → đổi thành `ZRAP_ASSET_ASGN`.

---

## 4. Hằng số và dữ liệu mẫu

### 4.1 Interface hằng số `ZIF_ASSET_LOAN_CONST`
*New → ABAP Interface* → dán `src/00_common/zif_asset_loan_const.intf.abap`.
Tập trung mọi mã status ở một chỗ (đúng gợi ý "Centralize status constants" của DET-004), tránh viết cứng `'03'` rải rác trong code.

### 4.2 Class dữ liệu mẫu `ZCL_ASSET_LOAN_DATA_GEN`
*New → ABAP Class* → dán `src/00_common/zcl_asset_loan_data_gen.clas.abap` → Activate → nhấn **F9** (Run as Console Application).

Class sẽ **xoá toàn bộ dữ liệu cũ** rồi tạo:
- Phòng ban IT, HR, FIN (+ 1 phòng inactive để test value help), địa điểm HCM01/HAN01/DAN01.
- Loại thiết bị: LAPTOP (30 ngày, priority 1), PHONE (14), MONIT (60), TABLET (30).
- 8 thiết bị (trong đó LT-0004 đang On Loan, LT-0005 ở Hà Nội → dùng để test lọc).
- **User hiện tại** thuộc phòng IT và là **approver cho mọi loại** → 1 user Trial có thể tự test toàn bộ luồng.

Kiểm tra: chuột phải bảng → *Open With → Data Preview*.

---

## 5. CDS master data và Value Help

*New → Other → Core Data Services → Data Definition*. Chọn template **defineViewEntity** (hoặc để trống), dán code, activate. Tạo **theo thứ tự**:

1. View master (không phụ thuộc gì ngoài bảng):
   `ZI_DEPARTMENT`, `ZI_LOCATION`, `ZI_ASSET_CATEGORY`, `ZI_ASSET_MASTER`, `ZI_APPROVER_TEXT`, `ZI_ASSET_LOAN_REQ_CNT`
2. Value help theo sheet 09:

| VH | View | Ghi chú |
|---|---|---|
| VH-001 | `ZI_DEPARTMENT_VH` | lọc `IsActive = 'X'` |
| VH-002 | `ZI_LOCATION_VH` | lọc `IsActive = 'X'` |
| VH-003 | `ZI_ASSET_CATEGORY_VH` | hiện thêm `MaxLoanDays` |
| VH-004 | `ZI_AVAILABLE_ASSET_VH` | chỉ asset `01 Available` + active |
| VH-005 | `ZI_ASSET_APPROVER_VH` | |
| VH-006 | `ZI_RETURN_CONDITION_VH` | đọc domain `ZRAP_D_CONDITION` |
| VH-007 | `ZI_ASSET_STATUS_VH` | đọc domain `ZRAP_D_ASSET_STATUS` |
| (thêm) | `ZI_REQ_STATUS_VH` | status request + **Criticality** (màu) |
| (thêm) | `ZI_ITEM_STATUS_VH`, `ZI_ASGN_STATUS_VH` | text status item/assignment |

Các annotation quan trọng:
- `@ObjectModel.dataCategory: #VALUE_HELP` – đánh dấu view là value help.
- `@Search.searchable` + `@Search.defaultSearchElement` – ô tìm kiếm trong dialog value help.
- `@ObjectModel.text.element` + `@Semantics.text` – hiển thị "IT (Information Technology)" thay vì chỉ mã.
- **Criticality**: `0` xám, `1` đỏ, `2` cam, `3` xanh lá, `5` xanh dương (sheet 03, cột *Criticality*).

`ZI_ASSET_LOAN_REQ_CNT` đếm số item và số asset đã gán của mỗi request → dùng cho cột *Requested Items* / *Assigned Assets* (LR-015, LR-016).

---

## 6. Abstract entity

Action có tham số (dialog nhập liệu) cần một *abstract entity* mô tả các trường của dialog.
*New → Data Definition* → template **defineAbstractEntity** → dán file trong `src/03_abstract/`.

| Abstract entity | Action | Trường |
|---|---|---|
| `ZA_ASSET_REJECT_PARAM` | Reject | Reason |
| `ZA_ASSET_CORR_PARAM` | ReturnForCorrection | Reason |
| `ZA_ASSET_CANCEL_PARAM` | Cancel | Reason |
| `ZA_ASSET_QTY_PARAM` | SetApprovedQuantity | ApprovedQuantity |
| `ZA_ASSET_ASSIGN_PARAM` | AssignAsset | CategoryID, LocationID (tự điền, để lọc), **AssetID** |
| `ZA_ASSET_RETURN_PARAM` | ReturnAsset | ReturnDate, ReturnCondition (VH), ReturnNote |
| `ZA_ASSET_LOST_PARAM` | ReportLost | LostDate, Note |

`ZA_ASSET_ASSIGN_PARAM` dùng `@UI.defaultValue: #('ELEMENT_OF_REFERENCED_ENTITY: ...')` để tự điền Category/Location từ item, và `additionalBinding ... usage: #FILTER` để value help asset **chỉ hiện laptop ở HCM01** nếu item là laptop và nơi nhận là HCM01 (VH-004, TC-033).

---

## 7. CDS Interface của BO

Đây là **mô hình dữ liệu** của Business Object 3 tầng (sheet 15, MAP-001…MAP-004):

```
ZI_ASSET_LOAN_REQUEST   (root)       composition [0..*] of ZI_ASSET_LOAN_ITEM
   ZI_ASSET_LOAN_ITEM   (child)      association to parent ZI_ASSET_LOAN_REQUEST
                                     composition [0..*] of ZI_ASSET_ASSIGNMENT
      ZI_ASSET_ASSIGNMENT (grandchild) association to parent ZI_ASSET_LOAN_ITEM
                                     association [1..1] to ZI_ASSET_LOAN_REQUEST  (_Request, để khoá/ủy quyền theo root)
```

**Cách tạo (quan trọng vì 3 view tham chiếu vòng tròn lẫn nhau):**
1. Tạo cả 3 Data Definition, dán code vào **nhưng chưa activate**.
2. Nhấn **Activate All** (`Ctrl+Shift+F3`) và tick cả 3 → activate cùng lúc.

Điểm cần hiểu:
- `define root view entity` chỉ dùng cho root.
- Tên trường đổi sang CamelCase (`request_uuid as RequestUUID`) — RAP dùng tên CDS, còn bảng dùng tên DB; phần `mapping` trong BDEF nối hai bên.
- `@Semantics.user.createdBy`, `@Semantics.systemDateTime.localInstanceLastChangedAt`… → RAP managed **tự điền** người tạo, thời gian sửa.
- Các association phụ (`_Department`, `_Status`, `_Counts`…) chỉ để đọc text/số đếm ở tầng projection.

---

## 8. Behavior Definition

### 8.1 Tạo BDEF
Chuột phải `ZI_ASSET_LOAN_REQUEST` → *New Behavior Definition* → Implementation type **Managed** → Finish. Xoá nội dung và dán `src/05_behavior/zi_asset_loan_request.bdef.asbdef`.

### 8.2 Sinh bảng draft
BDEF sẽ báo lỗi ở 3 dòng `draft table zrap_asset_rhd / rid / rad` vì bảng chưa có.
Đặt con trỏ lên tên bảng → **`Ctrl+1` (Quick Fix) → "Create draft table ..."** → ADT tự sinh cấu trúc → Activate. Làm cho cả 3 bảng.

> Bảng draft có tên trường **giống tên CDS viết thường** (`assetuuid`, `assignmentstatus`…) và có thêm `"%admin"`. Không sửa dữ liệu bảng draft trực tiếp — RAP tự quản lý. Nếu sau này bạn thêm trường vào CDS, phải **sinh lại** bảng draft (Ctrl+1 trên dòng `draft table` → regenerate).

### 8.3 Hiểu BDEF (đối chiếu Excel)

| Phần trong BDEF | Ý nghĩa | Excel |
|---|---|---|
| `managed with additional save` | RAP tự lưu 3 bảng; ta **thêm** logic lưu riêng để cập nhật `ZRAP_ASSET_MST` | DET-005 |
| `strict ( 2 )` | Bật kiểm tra nghiêm ngặt, chuẩn ABAP Cloud | Technical scope |
| `with draft` + `draft table` + `draft action Edit/Activate/Discard/Resume/Prepare` | Lưu nháp, chỉnh sửa an toàn | "Managed draft" |
| `lock master` / `lock dependent by _Request` | Khoá cả cây theo root | MAP-001…003 |
| `total etag`, `etag master` | Phát hiện sửa đồng thời | RAP locking/ETag |
| `authorization master ( global, instance )` | Kiểm tra quyền theo từng request (approver) | BR-012 |
| `field ( numbering : managed )` | UUID tự sinh | Managed numbering |
| `field ( readonly )` / `( mandatory )` | Trường chỉ đọc / bắt buộc trên UI | sheet 11 cột Editable/Mandatory |
| `update/delete ( features : instance )`, `action ( features : instance )` | Bật/tắt nút theo status | 08_Actions cột *Feature Control* |
| `determination ... on modify / on save` | Tự tính giá trị | 07_Determinations |
| `validation ... on save` + liệt kê trong `Prepare` | Kiểm tra khi lưu nháp/kích hoạt | 06_Business_Rules |
| `action ... parameter ZA_...` | Nút bấm có dialog | 08_Actions |

Bảng ánh xạ chi tiết:

| Excel ID | Tên trong BDEF | Trigger |
|---|---|---|
| DET-001 | `Request~setDefaultValues` | on modify { create } |
| DET-002 | `Item~setItemNumber` | on modify { create } |
| DET-003 | `Request~determineApprover`, `Item~determineApproverFromItem` | đổi DepartmentID / tạo item / đổi CategoryID |
| DET-004 | `Assignment~updateRequestStatus`, `Item~recalcOnQuantity` | đổi AssignmentStatus / ApprovedQuantity |
| DET-005 | Saver `save_modified` | khi lưu vào DB |
| (thêm) | `Request~setRequestId` | on save { create } – sinh mã 0000000001… |
| BR-001, 003, 004 | trong action `Submit` (+ `validateDates`) | |
| BR-002 | `Item~validateQuantity` | |
| BR-005 | action `SetApprovedQuantity` | |
| BR-006, 007, 008 | action `AssignAsset` | |
| BR-009 | action `Checkout` | |
| BR-010 | action `ReturnAsset` | |
| BR-011 | Saver | |
| BR-012 | `get_instance_authorizations` | |

### 8.4 Sinh class behavior pool
Activate BDEF lần đầu sẽ báo class `zbp_i_asset_loan_request` chưa tồn tại → đặt con trỏ lên dòng đầu → **`Ctrl+1` → "Create behavior implementation class"**. ADT tạo class với đầy đủ khung method.

---

## 9. Behavior Implementation

Mở class `ZBP_I_ASSET_LOAN_REQUEST`:
- Tab **Global Class**: giữ nguyên (giống `src/05_behavior/zbp_i_asset_loan_request.clas.abap`).
- Tab **Local Types**: **xoá hết** và dán `src/05_behavior/zbp_i_asset_loan_request.clas.locals_imp.abap`.
- Activate.

### 9.1 Cấu trúc file Local Types

| Class local | Vai trò |
|---|---|
| `lcl_helper` | Logic dùng chung: `determine_approver` (DET-003), `recalc_status` (DET-004) |
| `lhc_request` | Quyền, feature control, determination/validation của header, 6 action header |
| `lhc_item` | Đánh số item, validation số lượng/loại, action `SetApprovedQuantity`, `AssignAsset` |
| `lhc_assignment` | Action `ReturnAsset`, `ReportLost`, gọi tính lại status |
| `lsc_zi_asset_loan_request` | **Saver**: cập nhật status thiết bị trong `ZRAP_ASSET_MST` |

### 9.2 Các mẫu code RAP cần nắm (sẽ gặp lặp lại)

**Đọc dữ liệu trong buffer (EML READ):**
```abap
READ ENTITIES OF zi_asset_loan_request IN LOCAL MODE
  ENTITY Request
    FIELDS ( Status ApproverID ) WITH CORRESPONDING #( keys )
    RESULT DATA(requests).
```
- `IN LOCAL MODE`: bỏ qua kiểm tra quyền & feature control (vì đây là code nội bộ của BO).
- `%tky` = khoá giao dịch (gồm `%is_draft` + UUID) — luôn dùng `%tky` để code chạy đúng cho cả bản nháp lẫn bản active.

**Ghi dữ liệu (EML MODIFY), không `COMMIT`** – RAP tự commit:
```abap
MODIFY ENTITIES OF zi_asset_loan_request IN LOCAL MODE
  ENTITY Request
    UPDATE FIELDS ( Status ) WITH VALUE #( ( %tky = r-%tky Status = '02' ) ).
```

**Báo lỗi trong validation/action:**
```abap
APPEND VALUE #( %tky = r-%tky ) TO failed-request.          " chặn lưu / chặn action
APPEND VALUE #( %tky = r-%tky
                %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                              text     = 'Expected return date is invalid' )
                %element-ExpectedReturnDate = if_abap_behv=>mk-on ) TO reported-request.  " tô đỏ trường
```
`%state_area` dùng để xoá thông báo cũ của validation khi người dùng đã sửa đúng (quan trọng với draft).

**Action trả về `$self`:** đọc lại bản ghi và trả qua `result` để UI làm mới:
```abap
result = VALUE #( FOR r IN requests ( %tky = r-%tky %param = r ) ).
```

### 9.3 Giải thích từng phần

- **`get_instance_features`**: quyết định nút nào bật. Ví dụ `Approve` chỉ bật khi `Status = 02` **và** đang xem bản active (không phải bản nháp). `Edit/update` chỉ bật ở `01 Draft` và `05 In Correction` (sheet 11 – Editable rule).
- **`get_instance_authorizations`**: chỉ người có `ApproverID = user hiện tại` được Approve/Reject/Return (BR-012); chỉ requester được sửa/xoá/submit.
- **`setDefaultValues`** (DET-001): user hiện tại (`cl_abap_context_info=>get_user_technical_name( )`), ngày hiện tại, status 01, phòng ban lấy từ `ZRAP_USER_DEPT`.
- **`determine_approver`** (DET-003): với mỗi item, tìm cấu hình active trong `ZRAP_ASSET_APPR` theo (phòng ban, loại) và chọn loại có **priority nhỏ nhất (1 = cao nhất)**.
- **`submit`**: kiểm tra ≥1 item (BR-001), ngày trả ≥ ngày nhận (BR-003), số ngày ≤ `MAX_LOAN_DAYS` của từng loại (BR-004), đã có approver → chuyển 02.
- **`approve`**: chuyển 03 và gán `ApprovedQuantity = RequestedQuantity` (Asset Manager có thể giảm bằng `SetApprovedQuantity`).
- **`assignAsset`**: tìm asset theo `AssetID`; kiểm tra active + Available (BR-006), cùng loại và cùng địa điểm, chưa được gán ở request khác — kiểm tra cả bảng active, **bảng draft** và buffer hiện tại (BR-007), chưa vượt số lượng duyệt (BR-008) → `CREATE BY \_Assignments`.
- **`recalc_status`** (DET-004): đếm assignment của từng item → tính status item; tổng hợp lên request: đủ số → 06; sau checkout: còn mở + đã trả 1 phần → 08; không còn mở → 09 + `CompletionDate`.
- **`checkout`**: kiểm tra mọi item đã gán đủ (BR-009) → request 07, assignment 02, ngày checkout.
- **`returnAsset` / `reportLost`**: bắt buộc ngày + tình trạng (BR-010) → assignment 03 Returned (hoặc 04 Lost).
- **`cancel`**: bắt buộc lý do → request 10, assignment đang 01 → 05 (saver trả asset về Available).
- **Saver `save_modified`** (DET-005, BR-011): vì `ZRAP_ASSET_MST` **không thuộc BO**, ta chỉ được ghi vào nó ở **giai đoạn save**. Tạo assignment → asset 02 Reserved; checkout → 03 On Loan; trả Good → 01; trả Damaged/thiếu phụ kiện → 04 Maintenance; Lost → 06; Cancel → 01.

---

## 10. Projection layer

### 10.1 CDS projection
Tạo 3 Data Definition từ `src/06_projection/` (template **defineProjectionView**), **activate cùng lúc** như bước 7.

- `provider contract transactional_query` (chỉ trên root) – projection dành cho UI giao dịch.
- `redirected to composition child / to parent` – nối 3 view projection với nhau.
- Thêm trường text từ association: `_Department.DepartmentName as DepartmentName`, `_Status.Criticality as StatusCriticality`…
- `@Consumption.valueHelpDefinition` gắn value help vào trường.
- `@Metadata.allowExtensions: true` – cho phép tách annotation UI sang Metadata Extension.
- `ZC_ASSET_LOAN_ITEM` có thêm `_Request.LocationID as RequestLocationID` để dialog AssignAsset tự điền địa điểm.

### 10.2 Projection BDEF
Chuột phải `ZC_ASSET_LOAN_REQUEST` → *New Behavior Definition* (type **Projection**) → dán `zc_asset_loan_request.bdef.asbdef`.

Chỉ những gì ghi `use ...` mới xuất hiện trên UI. Ví dụ Assignment **không** `use create/update/delete` → người dùng chỉ thay đổi assignment qua action (đúng sheet 11: "Action controlled").

---

## 11. Metadata Extension

Chuột phải từng view projection → *New Metadata Extension* → dán file trong `src/07_ui_service/`:
- `ZC_ASSET_LOAN_REQUEST_MDE`, `ZC_ASSET_LOAN_ITEM_MDE`, `ZC_ASSET_ASSIGNMENT_MDE`.

| Annotation | Tác dụng | Excel |
|---|---|---|
| `@UI.headerInfo` | Tiêu đề Object Page (RequestID) | 11 – Header Information |
| `@UI.selectionField` | Ô lọc ở List Report | LR-001…LR-008 |
| `@UI.lineItem` | Cột trong bảng | LR-009…LR-018 |
| `@UI.lineItem: [{ type: #FOR_ACTION ... }]` | Nút trên toolbar bảng | |
| `@UI.identification: [{ type: #FOR_ACTION ... }]` | Nút trên header Object Page | 11 – Object Page Actions |
| `@UI.facet` | Các section của Object Page | 11 – Group / Facet |
| `@UI.fieldGroup: [{ qualifier: 'General' }]` | Gom trường vào từng section | 11 |
| `@UI.dataPoint` + `criticality` | Status có màu ở header | 11 – Header status |
| `@Consumption.filter.selectionType: #INTERVAL` | Lọc khoảng ngày | LR-005 |

Section *Assigned Physical Assets* (nhóm 70) nằm ở **Object Page của Item**: từ request bấm vào 1 dòng item → thấy bảng thiết bị đã gán (Fiori Elements hiển thị composition cấp 3 theo kiểu điều hướng).

---

## 12. Service và Preview

1. **Service Definition**: chuột phải `ZC_ASSET_LOAN_REQUEST` → *New Service Definition* → tên `ZUI_ASSET_LOAN` → dán `zui_asset_loan.srvd.srvdsrv` → Activate.
2. **Service Binding**: chuột phải `ZUI_ASSET_LOAN` → *New Service Binding* → tên `ZUI_ASSET_LOAN_O4`, Binding Type **OData V4 - UI** → Activate.
3. Mở binding → bấm **Publish** (lần đầu mất ~1 phút).
4. Chọn entity `LoanRequest` → **Preview** → trình duyệt mở app Fiori Elements.

---

## 13. Test

### 13.1 Luồng chính (TC-040)

| # | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | **Create** | Mở bản nháp, Requester/Request Date/Department (IT) tự điền, status Draft |
| 2 | Chọn Location `HCM01`, Needed From hôm nay, Expected Return +10 ngày, Purpose | |
| 3 | Ở bảng Items: **Create** → Category `LAPTOP`, Qty `2` | Item No. = 001 tự sinh |
| 4 | **Save** | Request ID `0000000001`, Approver được điền |
| 5 | **Submit** | Status Submitted (xanh dương) |
| 6 | **Approve** | Approved (xanh lá), Approved Qty = 2 |
| 7 | Vào item → **Assign Asset** → value help chỉ hiện laptop Available tại HCM01 → chọn `LT-0001` | 1 dòng trong *Assigned Physical Assets*, asset LT-0001 → Reserved |
| 8 | **Assign Asset** `LT-0002` | Request → Asset Assigned; nút Assign Asset bị tắt |
| 9 | Quay lại request → **Checkout** | Checked Out, assignments Checked Out, asset On Loan |
| 10 | Item → assignment LT-0001 → **Return Asset** (Good) | Request Partially Returned; LT-0001 → Available |
| 11 | LT-0002 → **Return Asset** (Damaged) | Request Completed + Completion Date; LT-0002 → Maintenance |

Kiểm tra asset bằng *Data Preview* bảng `ZRAP_ASSET_MST`.

### 13.2 Test case lỗi (sheet 13)

| Test | Cách làm | Mong đợi |
|---|---|---|
| TC-001 | Tạo request không item → Save → Submit | "Please add at least one requested asset item" |
| TC-002 | Item Qty = 0 → Save | Lỗi đỏ ở trường Requested Qty, không lưu được |
| TC-003 | Needed 2026-10-01, Return 2026-09-30 | "Expected return date is invalid" |
| TC-004 | LAPTOP, mượn 45 ngày → Submit | "Loan duration exceeds maximum…" |
| TC-006 | Assign `LT-0004` (đang On Loan) | "Selected asset is not available" |
| TC-007 | Assign cùng 1 asset 2 lần | "Asset is already assigned…" |
| TC-009 | Approved 2, mới gán 1 → Checkout | Nút Checkout bị tắt (feature control); gọi qua API sẽ báo "Assign all approved assets before checkout" |
| TC-010 | Return Asset bỏ trống Condition | "Return date and condition are required" |
| TC-011 | Return Damaged | Assignment Returned, asset Maintenance |
| TC-033 | Value help asset của item LAPTOP/HCM01 | Không thấy LT-0005 (Hà Nội), LT-0004 (On Loan) |
| BR-012 | Đổi `APPROVER_ID` trong `ZRAP_ASSET_APPR` sang user khác, tạo request mới, Submit, Approve | Approve bị từ chối (không có quyền) |

> Chạy lại `ZCL_ASSET_LOAN_DATA_GEN` (F9) bất cứ lúc nào để reset dữ liệu.

---

## 14. Lỗi thường gặp

| Hiện tượng | Nguyên nhân / Cách xử lý |
|---|---|
| "Object ... already exists" khi tạo | Trial dùng chung → thêm hậu tố cá nhân cho tên |
| CDS báo không tìm thấy view con/cha | Activate cả nhóm bằng `Ctrl+Shift+F3` |
| BDEF lỗi ở `draft table` | Chưa sinh bảng draft → `Ctrl+1` |
| Sau khi thêm trường vào CDS, lỗi draft | Sinh lại bảng draft (`Ctrl+1` trên dòng `draft table`) |
| Lỗi tên trường bảng `zrap_asset_rad` trong `assignAsset` | Mở bảng draft vừa sinh, xem tên trường thật (`assetuuid`, `assignmentstatus`) và sửa câu `SELECT` cho khớp |
| Text status trống | Chưa nhập fixed value text cho domain, hoặc đăng nhập khác ngôn ngữ EN |
| Nút action không hiện | Thiếu `use action` trong projection BDEF hoặc thiếu `@UI.lineItem/identification #FOR_ACTION` |
| Nút action hiện nhưng xám | Đúng thiết kế — kiểm tra status trong `get_instance_features` |
| Dialog AssignAsset không tự điền Category/Location | Bản UI5 không hỗ trợ `@UI.defaultValue` cho parameter → tự nhập/lọc trong value help; backend vẫn kiểm tra khớp loại/địa điểm |
| Preview cũ, không thấy thay đổi annotation | Tải lại trình duyệt với `Ctrl+F5`; xoá cache (`/sap/bc/ui2/flp?sap-ui-xx-noCache`) |
| Debug | Đặt breakpoint trong tab Local Types (double-click lề trái), chạy Preview → Eclipse dừng lại |

---

## 15. Khác biệt so với Excel

| Điểm | Excel | Code mẫu | Lý do |
|---|---|---|---|
| Tên bảng assignment | `ZRAP_ASSET_ASSIGN` | `ZRAP_ASSET_ASGN` | Giới hạn 16 ký tự |
| Tham số AssignAsset | `AssetUUID` | `AssetID` (+ Category/Location để lọc) | Người dùng không đọc được UUID; code tự tra UUID |
| Lý do Cancel | Không có trường | Lưu vào `REJECTION_REASON` | Bảng không có `CANCEL_REASON`; có thể thêm trường nếu reviewer muốn |
| Submit metadata (user/thời gian submit) | "set submit metadata" | Không lưu | Bảng không có trường; thêm `SUBMITTED_BY/AT` nếu cần |
| Mã status Item/Assignment/Cancelled | Chỉ có tên | Tự đặt mã (xem bước 2) | Excel chưa định nghĩa mã |
| Request ID | "Generated unique" | MAX + 1 (on save) | Đơn giản cho Trial; production nên dùng Number Range Object |
| Vai trò Asset Manager | Role-based | Ai cũng làm được action của Asset Manager; chỉ kiểm tra Requester/Approver | IAM production nằm ngoài scope (sheet 01) |
| Return "Missing accessories" | Không nêu | Asset → Maintenance | Chỉ Good mới về Available |
| Cancel được ở status 06 | Draft/Submitted/Approved | Thêm 06 Asset Assigned | Để giải phóng asset đã reserve |

---

## 16. Mở rộng

- **Ẩn/hiện trường theo status** (Rejection Reason chỉ hiện khi Rejected…): thêm trường boolean tính toán ở projection rồi dùng `@UI.hidden: #(TênTrường)`.
- **Bắt buộc nhập trong dialog**: tạo BDEF cho abstract entity với `field ( mandatory : execute ) Reason;`.
- **Side effects** (tự làm mới bảng assignment sau AssignAsset): thêm khối `side effects { action AssignAsset affects entity _Assignments; }` trong BDEF item và `use side effects;` trong projection.
- **Phân quyền thật**: tạo Access Control (DCL) cho `ZC_ASSET_LOAN_REQUEST` và Authorization Object riêng, kiểm tra trong `get_global_authorizations`.
- **Triển khai app Fiori thật** (ngoài Preview): dùng SAP Business Application Studio → *Fiori Generator → List Report Page* → chọn service `ZUI_ASSET_LOAN_O4` → Deploy về ABAP Environment, tạo IAM App + Business Catalog để đưa lên Launchpad.
- **Unit test EML**: tạo class test với `cl_botd_txbufdbl_bo_test_environment` theo tutorial RAP100.

## Tài liệu tham khảo (sheet 14)

- SAP RAP100 Tutorial: <https://developers.sap.com/tutorials/group-build-an-sap-fiori-app-using-the-abap-restful-application-programming-model-rap100>
- SAP Community – End-to-end clean core RAP trên Trial: <https://community.sap.com/t5/technology-blog-posts-by-sap/an-end-to-end-hands-on-tutorial-for-clean-core-rap-development/ba-p/14276157>
- ABAP RAP Keyword Documentation (trong ADT: `F1` trên từ khoá bất kỳ).
