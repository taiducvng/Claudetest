# IT Asset Loan & Return Management — SAP RAP + Fiori Elements

Sample implementation of design document **DD-RAP-ASSET-001 v1.1** for SAP BTP ABAP Environment (Trial):
RAP managed BO with draft, 3-level composition (Request → Item → Assignment), OData V4, Fiori Elements.

- 📘 Step-by-step guide (Vietnamese): [`docs/HUONG_DAN_TRIEN_KHAI.md`](docs/HUONG_DAN_TRIEN_KHAI.md)
- 💻 Source code, in creation order: [`src/`](src)

| Folder | Content |
|---|---|
| `src/00_common` | Status constants interface, demo data generator class |
| `src/01_tables` | 9 custom tables |
| `src/02_master_cds` | Master data views, value helps, counter view |
| `src/03_abstract` | Action parameter entities |
| `src/04_bo_interface` | Interface CDS views (BO data model) |
| `src/05_behavior` | Behavior definition + behavior pool |
| `src/06_projection` | Projection CDS views + projection behavior |
| `src/07_ui_service` | Metadata extensions (UI) + service definition |

Domains (`ZRAP_D_*`) and generated draft tables are created in ADT; see the guide.
