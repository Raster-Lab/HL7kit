# HL7 v3.x Standards Analysis

## Overview

HL7 Version 3.x represents a fundamental shift from the HL7 v2.x pipe-delimited messaging to a comprehensive, XML-based messaging standard built on a formal Reference Information Model (RIM). This document provides a comprehensive analysis of HL7 v3.x specifications, including the RIM, Clinical Document Architecture (CDA), data types, and implementation considerations for the HL7kit framework.

---

## HL7 v3 Architecture

### Philosophical Shift

Unlike HL7 v2.x's pragmatic, event-driven approach, HL7 v3 was designed as a formal, model-driven standard that:
- Uses the Reference Information Model (RIM) as a single, unified information model
- Employs XML for all message encoding
- Leverages formal modeling methodologies (UML, RIM)
- Provides semantic interoperability through standardized vocabulary bindings
- Ensures consistent structure across all message types

### Key Components

1. **Reference Information Model (RIM)** - The foundational abstract information model
2. **Data Types** - Formal specification of all data structures
3. **Vocabulary** - Standard code systems and value sets
4. **Clinical Document Architecture (CDA)** - Document-based information exchange
5. **Message Types** - Specific interaction patterns derived from the RIM

---

## Reference Information Model (RIM)

The RIM is the cornerstone of HL7 v3, providing a single, coherent information model from which all HL7 v3 specifications are derived. It represents healthcare concepts using an object-oriented approach with six core classes.

### Core Classes

#### 1. Act

**Purpose:** Represents any action, event, or occurrence in healthcare.

**Key Attributes:**
- `classCode` - Type of act (Observation, Procedure, Encounter, etc.)
- `moodCode` - Intent or status (Event, Intent, Order, Request, etc.)
- `code` - Specific type of the act
- `statusCode` - Current state (active, completed, aborted, etc.)
- `effectiveTime` - When the act occurred or was planned
- `activityTime` - Duration of the act
- `reasonCode` - Why the act was performed

**Mood Codes:**
- `EVN` (Event) - Something that has occurred
- `INT` (Intent) - Something intended to happen
- `PRMS` (Promise) - A commitment to perform
- `RQO` (Request) - An order or request
- `DEF` (Definition) - A template or protocol

**Common Subclasses:**
- **Observation** - Clinical findings, lab results, vital signs
- **Procedure** - Surgical operations, treatments
- **Encounter** - Patient visits, admissions
- **SubstanceAdministration** - Medication administration
- **Supply** - Provision of materials or devices

**Examples:**
- Blood pressure measurement (Observation)
- Appendectomy (Procedure)
- Hospital admission (Encounter)
- Insulin injection (SubstanceAdministration)

#### 2. Entity

**Purpose:** Represents physical things or beings in healthcare.

**Key Attributes:**
- `classCode` - Type of entity (Person, Organization, Place, Device, Material)
- `determinerCode` - Whether specific or generic instance
- `code` - Specific type of the entity
- `name` - Names associated with the entity
- `desc` - Description of the entity
- `statusCode` - Current state (active, inactive, etc.)

**Common Subclasses:**
- **Person** - Patients, providers, family members
- **Organization** - Hospitals, clinics, insurance companies
- **Place** - Locations, rooms, buildings
- **Device** - Medical equipment, instruments
- **Material** - Medications, supplies, specimens

**Examples:**
- Dr. Jane Smith (Person)
- Mayo Clinic (Organization)
- Operating Room 5 (Place)
- Insulin pump (Device)
- Penicillin (Material)

#### 3. Role

**Purpose:** Defines the capacity or function an entity assumes within healthcare contexts.

**Key Attributes:**
- `classCode` - Type of role (Patient, Provider, Employee, etc.)
- `code` - Specific role type
- `statusCode` - Current state of the role
- `effectiveTime` - When the role is active

**Common Role Types:**
- **Patient** - Entity in the patient role
- **Provider** - Healthcare provider role
- **Employee** - Organizational employee role
- **Guardian** - Legal guardian role
- **Licensed Entity** - Licensed professional role

**Examples:**
- John Doe as a patient
- Dr. Smith as a cardiologist
- Nurse Jones as a registered nurse
- Mary Brown as guardian of minor patient

#### 4. Participation

**Purpose:** Expresses how an entity (in some role) participates in an act.

**Key Attributes:**
- `typeCode` - Type of participation
- `time` - When the participation occurred
- `modeCode` - Method of participation (verbal, written, electronic)
- `awarenessCode` - Level of awareness of the participant

**Participation Types:**
- `AUT` (Author) - Created or originated the act
- `PRF` (Performer) - Actually carried out the act
- `SBJ` (Subject) - The target or focus of the act
- `INF` (Informant) - Provided information
- `RESP` (Responsible Party) - Legally responsible
- `VRF` (Verifier) - Verified accuracy
- `LOC` (Location) - Where the act took place
- `RCV` (Receiver) - Intended recipient

**Examples:**
- Dr. Smith (performer) performed the surgery
- Patient John Doe (subject) received the treatment
- Nurse Jones (informant) reported the vital signs
- Operating Room 5 (location) where surgery occurred

#### 5. ActRelationship

**Purpose:** Describes relationships between acts, modeling complex clinical workflows.

**Key Attributes:**
- `typeCode` - Type of relationship
- `inversionInd` - Whether relationship is inverted
- `contextConductionInd` - Whether context propagates

**Relationship Types:**
- `COMP` (Component) - Part of a larger act
- `SUBJ` (Subject) - Act is about another act
- `CAUS` (Causative) - Act caused another act
- `RSON` (Reason) - Justification for the act
- `FLFS` (Fulfills) - Satisfies an order or intent
- `SEQL` (Sequel) - Follows in a sequence

**Examples:**
- Lab order (intent) fulfilled by lab result (event)
- Chest pain (observation) caused diagnostic test (procedure)
- Medication administration (event) follows medication order (request)

#### 6. RoleLink

**Purpose:** Shows relationships between roles.

**Key Attributes:**
- `typeCode` - Type of relationship between roles

**Relationship Types:**
- `REL` (Related) - Generic relationship
- `BACKUP` - Backup or substitute relationship
- `PART` - Part of relationship (sub-organization)

**Examples:**
- Dr. Smith (primary physician) has backup Dr. Jones
- Cardiology department part of hospital organization
- Patient's primary care provider relationship

### RIM Principles

1. **Single Source of Truth** - All HL7 v3 specifications derive from the RIM
2. **Formal Semantics** - Precise meaning through structured relationships
3. **Extensibility** - Can be specialized for specific domains
4. **Consistency** - Common patterns across all healthcare domains
5. **Backward Compatibility** - Specializations cannot violate RIM constraints

---

## HL7 v3 Data Types

HL7 v3 defines a comprehensive, hierarchical data type system. All data types are formally specified with constraints and validation rules.

### Primitive Data Types

#### Boolean (BL)
- **Purpose:** Logical true/false values
- **Values:** `true`, `false`, or null flavors
- **Operations:** AND, OR, NOT, XOR
- **Usage:** Yes/no questions, flags, binary states

#### Integer (INT)
- **Purpose:** Whole numbers
- **Range:** -∞ to +∞
- **Usage:** Counts, sequence numbers, discrete quantities
- **Examples:** Patient age: 45, number of medications: 3

#### Real (REAL)
- **Purpose:** Decimal numbers
- **Precision:** Arbitrary precision
- **Usage:** Measurements, quantities with fractions
- **Examples:** Body temperature: 98.6, lab value: 3.1415

#### String (ST)
- **Purpose:** Character strings
- **Encoding:** Unicode (UTF-8, UTF-16)
- **Usage:** Names, descriptions, free text
- **Max Length:** Implementation-defined
- **Examples:** Patient name, medication name

### Quantity Data Types

#### Physical Quantity (PQ)
- **Components:** Value (REAL) + Unit
- **Units:** UCUM (Unified Code for Units of Measure)
- **Usage:** Measurements with units
- **Examples:** 
  - Weight: 70 kg
  - Height: 180 cm
  - Blood pressure: 120 mm[Hg]

#### Monetary Amount (MO)
- **Components:** Value (REAL) + Currency
- **Usage:** Financial amounts
- **Examples:** $150.00 USD, €75.50 EUR

### Temporal Data Types

#### Point in Time (TS)
- **Purpose:** Single point in time
- **Precision:** Year down to fractional seconds
- **Format:** ISO 8601 compliant (YYYYMMDDHHMMSS.UUUU+ZZZZ)
- **Timezone:** Optional timezone offset
- **Examples:**
  - `20230615` - June 15, 2023
  - `20230615143000` - June 15, 2023 at 2:30 PM
  - `20230615143000.000-0500` - With timezone

#### Interval of Time (IVL<TS>)
- **Purpose:** Time range or interval
- **Components:** 
  - `low` - Start time
  - `high` - End time
  - `width` - Duration
  - `center` - Midpoint
- **Usage:** Effective periods, validity ranges
- **Examples:**
  - Prescription effective from 2023-01-01 to 2023-12-31
  - Hospital admission from 2023-06-15 09:00 to 2023-06-17 14:30

#### Date (DATE)
- **Purpose:** Calendar date without time
- **Format:** YYYYMMDD
- **Examples:** Birth date, due date

#### Time (TIME)
- **Purpose:** Time of day without date
- **Format:** HHMMSS
- **Examples:** Medication administration time

### Coded Data Types

#### Instance Identifier (II)
- **Purpose:** Unique identifier for any instance
- **Components:**
  - `root` - OID or UUID identifying the assigning authority
  - `extension` - Optional local identifier within that authority
- **Usage:** Patient IDs, document IDs, any unique references
- **Examples:**
  - Patient ID: root="2.16.840.1.113883.4.1", extension="123-45-6789"
  - Document ID: root="2.16.840.1.113883.3.72.5.9.1", extension="DOC-12345"

#### Concept Descriptor (CD)
- **Purpose:** Most comprehensive coded value data type
- **Components:**
  - `code` - The primary code value
  - `codeSystem` - OID of the code system
  - `codeSystemName` - Human-readable code system name
  - `codeSystemVersion` - Version of the code system
  - `displayName` - Human-readable name
  - `originalText` - Source text the code represents
  - `translation` - Alternative codes from other vocabularies
  - `qualifier` - Modifies or refines the concept
- **Usage:** Most clinical concepts
- **Examples:**
  - Diagnosis code: SNOMED CT 38341003 "Hypertension"
  - Lab test: LOINC 2160-0 "Creatinine"

#### Coded With Equivalents (CE)
- **Purpose:** Simpler coded value with translations
- **Inherits From:** CD
- **Components:**
  - Primary code (code, codeSystem, displayName)
  - Alternative codes (translations)
- **Usage:** When multiple equivalent codes may exist
- **Examples:**
  - Medication: RxNorm code with NDC translation

#### Coded Value (CV)
- **Purpose:** Simple coded value
- **Components:**
  - `code` - The code value
  - `codeSystem` - Code system OID
- **Usage:** Value sets, enumerations
- **Examples:** Gender code, status code

#### Coded Simple (CS)
- **Purpose:** Simplest coded value (just the code)
- **Usage:** HL7-defined code values
- **Examples:** Act mood code, entity class code

### Collection Data Types

#### Set (SET<T>)
- **Purpose:** Unordered collection of unique values
- **Type Parameter:** T can be any data type
- **Usage:** Multiple values where order doesn't matter
- **Examples:**
  - Multiple telephone numbers
  - Set of allergies

#### List (LIST<T>)
- **Purpose:** Ordered collection of values
- **Type Parameter:** T can be any data type
- **Usage:** Ordered sequences
- **Examples:**
  - Ordered list of medications
  - Sequence of procedures

#### Bag (BAG<T>)
- **Purpose:** Unordered collection allowing duplicates
- **Type Parameter:** T can be any data type
- **Usage:** Collections where count matters but order doesn't

#### Interval (IVL<T>)
- **Purpose:** Range between two values
- **Type Parameter:** T can be any ordered type (INT, TS, PQ, etc.)
- **Components:** low, high, width, center
- **Usage:** Ranges of values
- **Examples:**
  - Age range: 18-65
  - Blood pressure range: 120-140

### Complex Data Types

#### Entity Name (EN)
- **Purpose:** Person or organization names
- **Components:**
  - `use` - Name usage (legal, maiden, alias, etc.)
  - `parts` - Name parts (family, given, prefix, suffix)
  - `validTime` - When name is valid
- **Examples:**
  - Dr. John Q. Smith Jr., M.D.
  - Family: Smith, Given: John, Given: Q, Prefix: Dr., Suffix: Jr., Suffix: M.D.

#### Person Name (PN)
- **Inherits From:** EN
- **Specific To:** Person names
- **Usage:** Patient names, provider names

#### Organization Name (ON)
- **Inherits From:** EN
- **Specific To:** Organization names
- **Usage:** Hospital names, clinic names

#### Address (AD)
- **Purpose:** Postal or physical addresses
- **Components:**
  - `use` - Address usage (home, work, temporary, etc.)
  - `parts` - Address lines, city, state, postal code, country
  - `validTime` - When address is valid
- **Examples:**
  - 123 Main St, Suite 100, Springfield, IL 62701, USA

#### Telecommunication Address (TEL)
- **Purpose:** Phone, email, fax, URL
- **Components:**
  - `value` - The actual address (URI format)
  - `use` - Usage (home, work, mobile, etc.)
  - `validTime` - When address is valid
- **Examples:**
  - tel:+1-217-555-1234
  - mailto:patient@example.com
  - http://www.example.com

### Null Flavors

All data types can have null flavors to express why a value is missing:

- `NI` (No Information) - Value not provided
- `NA` (Not Applicable) - Value doesn't apply
- `UNK` (Unknown) - Value exists but is unknown
- `ASKU` (Asked but Unknown) - Information was sought but not found
- `NAV` (Temporarily Unavailable) - Not available at this time
- `NASK` (Not Asked) - Information was not sought
- `MSK` (Masked) - Value exists but was not disclosed for privacy
- `OTH` (Other) - Description in originalText

---

## Clinical Document Architecture (CDA)

CDA is an HL7 v3 standard for clinical document exchange. CDA documents are XML-based, human-readable, and machine-processable.

### CDA Document Structure

#### Header
The header contains document metadata:

- **Document Identification**
  - `id` - Unique document identifier
  - `setId` - Document set identifier (for versioning)
  - `versionNumber` - Version within the set
  
- **Document Type**
  - `code` - Type of document (LOINC code)
  - `title` - Human-readable title
  
- **Document Context**
  - `effectiveTime` - Document creation time
  - `confidentialityCode` - Privacy level
  - `languageCode` - Document language
  
- **Participants**
  - `recordTarget` - The patient (subject)
  - `author` - Document creator(s)
  - `custodian` - Document maintainer
  - `authenticator` - Legal authenticator
  - `legalAuthenticator` - Primary legal authenticator
  - `informant` - Information source
  
- **Context Information**
  - `documentationOf` - The encounter documented
  - `componentOf` - Encompassing encounter
  - `authorization` - Consent information

#### Body

The body contains the clinical content and can be:

1. **Non-structured Body** - Single narrative block
2. **Structured Body** - Organized sections and entries

### Sections

Sections organize content into meaningful clinical groupings:

**Common Section Types (LOINC codes):**
- `10160-0` - History of Medication Use
- `48765-2` - Allergies and Adverse Reactions
- `11450-4` - Problem List
- `30954-2` - Relevant Diagnostic Tests and Laboratory Data
- `8716-3` - Vital Signs
- `29545-1` - Physical Findings
- `10164-2` - History of Present Illness
- `10187-3` - Review of Systems
- `10157-6` - History of Family Member Diseases
- `10160-0` - History of Medication Use

**Section Structure:**
```xml
<section>
  <templateId root="2.16.840.1.113883.10.20.22.2.6.1"/>
  <code code="48765-2" codeSystem="2.16.840.1.113883.6.1" 
        displayName="Allergies and Adverse Reactions"/>
  <title>Allergies</title>
  <text>
    <!-- Human-readable narrative (required) -->
    <list>
      <item>Penicillin - Anaphylaxis</item>
    </list>
  </text>
  <!-- Machine-readable entries (optional) -->
  <entry>
    <!-- Structured clinical data -->
  </entry>
</section>
```

### Entries

Entries provide structured, coded clinical data within sections:

**Common Entry Types:**
- **Observation** - Clinical findings, lab results, vital signs
- **Procedure** - Surgical procedures, treatments
- **SubstanceAdministration** - Medication administration
- **Encounter** - Patient visits
- **Supply** - Medical supply provision
- **Act** - Generic clinical acts

**Entry Example:**
```xml
<entry>
  <observation classCode="OBS" moodCode="EVN">
    <templateId root="2.16.840.1.113883.10.20.22.4.7"/>
    <id root="2.16.840.1.113883.3.72.5.9.1" extension="Allergy1"/>
    <code code="ASSERTION" codeSystem="2.16.840.1.113883.5.4"/>
    <statusCode code="completed"/>
    <effectiveTime>
      <low value="20150101"/>
    </effectiveTime>
    <value xsi:type="CD" code="419199007" 
           codeSystem="2.16.840.1.113883.6.96" 
           displayName="Allergy to substance"/>
    <participant typeCode="CSM">
      <participantRole classCode="MANU">
        <playingEntity classCode="MMAT">
          <code code="7980" codeSystem="2.16.840.1.113883.6.88" 
                displayName="Penicillin"/>
        </playingEntity>
      </participantRole>
    </participant>
  </observation>
</entry>
```

### CDA Levels

1. **Level 1** - Non-structured body (single narrative block)
2. **Level 2** - Structured sections with narrative
3. **Level 3** - Structured sections with coded entries

### C-CDA (Consolidated CDA)

C-CDA is the U.S. implementation guide for CDA, defining specific templates and constraints:

**Common C-CDA Document Types:**
- **Continuity of Care Document (CCD)** - Comprehensive patient summary
- **Discharge Summary** - Hospital discharge information
- **Progress Note** - Clinical progress documentation
- **Operative Note** - Surgical procedure documentation
- **Consultation Note** - Specialist consultation
- **History and Physical (H&P)** - Initial patient evaluation
- **Procedure Note** - Procedure documentation
- **Care Plan** - Patient care planning

---

## Implementation Considerations for HL7kit

### Memory Efficiency

1. **Lazy XML Parsing** - Parse document structure on demand
2. **Streaming Parser** - Process large documents without full DOM
3. **Object Pooling** - Reuse RIM class instances
4. **Value Types** - Use Swift structs where appropriate for copy-on-write

### Concurrency

1. **Actor-Based Design** - Thread-safe document processing
2. **Async/Await** - Non-blocking XML parsing and validation
3. **Sendable Conformance** - Safe concurrent access to documents

### Validation

1. **Schema Validation** - Validate against CDA XSD schemas
2. **Template Validation** - Verify conformance to C-CDA templates
3. **Business Rules** - Enforce cardinality and data type constraints
4. **Vocabulary Validation** - Verify codes against value sets

### Performance Targets

- **Parsing Speed:** >1,000 CDA documents/second
- **Memory Usage:** <50MB for typical CDA document
- **Validation Time:** <100ms per document
- **XML Generation:** <50ms per document

---

## Standards References

### Official HL7 Specifications

- **HL7 Version 3 Standard** - ISO/HL7 21731:2014
- **RIM Version 3.0+** - HL7 Reference Information Model
- **CDA Release 2.0** - HL7 Clinical Document Architecture
- **C-CDA Release 2.1** - Consolidated CDA Implementation Guide
- **HL7 V3 Data Types** - Abstract Specification R2

### Code Systems

- **LOINC** (2.16.840.1.113883.6.1) - Laboratory and clinical observations
- **SNOMED CT** (2.16.840.1.113883.6.96) - Clinical terminology
- **RxNorm** (2.16.840.1.113883.6.88) - Medications
- **ICD-10-CM** (2.16.840.1.113883.6.90) - Diagnoses
- **CPT** (2.16.840.1.113883.6.12) - Procedures

### Implementation Guides

- **C-CDA 2.1** - U.S. Realm implementation guide
- **IHE Profiles** - Integration profiles using HL7 v3
- **National Extensions** - Country-specific adaptations

---

## Comparison: HL7 v2.x vs. HL7 v3.x

| Aspect | HL7 v2.x | HL7 v3.x |
|--------|----------|----------|
| **Encoding** | Pipe-delimited text | XML |
| **Model** | Event-driven messages | RIM-based formal model |
| **Structure** | Segments, fields, components | Acts, entities, roles, participations |
| **Adoption** | Very high (90%+ healthcare interfaces) | Moderate (CDA widely used) |
| **Flexibility** | Very flexible, lots of optionality | Structured, formal constraints |
| **Versioning** | Backward compatible across versions | Strict RIM conformance |
| **Complexity** | Relatively simple | More complex, requires RIM knowledge |
| **Document Exchange** | Message-based | Document-based (CDA) |
| **Use Cases** | Real-time transactions, orders, results | Clinical documents, summaries |

---

## Glossary

- **Act** - Any healthcare action or event
- **CDA** - Clinical Document Architecture
- **CD** - Concept Descriptor (coded value)
- **Entity** - Physical thing or being
- **II** - Instance Identifier (unique ID)
- **OID** - Object Identifier (globally unique dot-notation)
- **Participation** - How an entity participates in an act
- **RIM** - Reference Information Model
- **Role** - Capacity or function of an entity
- **TS** - Time Stamp (point in time)
- **UUID** - Universally Unique Identifier

---

*This document serves as the foundation for implementing HL7 v3.x support in HL7kit, focusing on the RIM core classes, data types, and CDA document processing.*
