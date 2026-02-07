import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for Subcomponent, Component, and Field structures
final class DataStructuresTests: XCTestCase {
    
    // MARK: - Subcomponent Tests
    
    func testSubcomponentSimpleValue() {
        let subcomponent = Subcomponent(rawValue: "Smith")
        
        XCTAssertEqual(subcomponent.raw, "Smith")
        XCTAssertFalse(subcomponent.isEmpty)
    }
    
    func testSubcomponentEmpty() {
        let subcomponent = Subcomponent(rawValue: "")
        
        XCTAssertEqual(subcomponent.raw, "")
        XCTAssertTrue(subcomponent.isEmpty)
    }
    
    func testSubcomponentValueAsync() async throws {
        let subcomponent = Subcomponent(rawValue: "Simple\\F\\Value")
        let value = try await subcomponent.value()
        
        XCTAssertEqual(value, "Simple|Value")
    }
    
    func testSubcomponentEncode() async {
        let subcomponent = await Subcomponent.encode("Value|With^Delimiters")
        
        XCTAssertEqual(subcomponent.raw, "Value\\F\\With\\S\\Delimiters")
    }
    
    func testSubcomponentDescription() {
        let subcomponent = Subcomponent(rawValue: "TestValue")
        XCTAssertEqual(subcomponent.description, "TestValue")
    }
    
    func testSubcomponentEquatable() {
        let sub1 = Subcomponent(rawValue: "Smith")
        let sub2 = Subcomponent(rawValue: "Smith")
        let sub3 = Subcomponent(rawValue: "Jones")
        
        XCTAssertEqual(sub1, sub2)
        XCTAssertNotEqual(sub1, sub3)
    }
    
    // MARK: - Component Tests
    
    func testComponentSimpleValue() {
        let component = Component.parse("Smith")
        
        XCTAssertEqual(component.count, 1)
        XCTAssertEqual(component.value.raw, "Smith")
        XCTAssertEqual(component[0].raw, "Smith")
    }
    
    func testComponentWithSubcomponents() {
        let component = Component.parse("Smith&John&A")
        
        XCTAssertEqual(component.count, 3)
        XCTAssertEqual(component[0].raw, "Smith")
        XCTAssertEqual(component[1].raw, "John")
        XCTAssertEqual(component[2].raw, "A")
    }
    
    func testComponentEmpty() {
        let component = Component.parse("")
        
        XCTAssertEqual(component.count, 1)
        XCTAssertTrue(component.isEmpty)
    }
    
    func testComponentOutOfBoundsAccess() {
        let component = Component.parse("Smith")
        
        let outOfBounds = component[5]
        XCTAssertEqual(outOfBounds.raw, "")
        XCTAssertTrue(outOfBounds.isEmpty)
    }
    
    func testComponentSerialize() {
        let sub1 = Subcomponent(rawValue: "Smith")
        let sub2 = Subcomponent(rawValue: "John")
        let sub3 = Subcomponent(rawValue: "A")
        let component = Component(subcomponents: [sub1, sub2, sub3])
        
        XCTAssertEqual(component.serialize(), "Smith&John&A")
    }
    
    func testComponentDescription() {
        let component = Component.parse("Smith&John&A")
        XCTAssertEqual(component.description, "Smith&John&A")
    }
    
    func testComponentAllSubcomponents() {
        let component = Component.parse("A&B&C")
        let all = component.all
        
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].raw, "A")
        XCTAssertEqual(all[1].raw, "B")
        XCTAssertEqual(all[2].raw, "C")
    }
    
    func testComponentEquatable() {
        let comp1 = Component.parse("Smith&John")
        let comp2 = Component.parse("Smith&John")
        let comp3 = Component.parse("Jones&Jane")
        
        XCTAssertEqual(comp1, comp2)
        XCTAssertNotEqual(comp1, comp3)
    }
    
    // MARK: - Field Tests
    
    func testFieldSimpleValue() {
        let field = Field.parse("Smith")
        
        XCTAssertEqual(field.repetitionCount, 1)
        XCTAssertEqual(field.value.value.raw, "Smith")
    }
    
    func testFieldWithComponents() {
        let field = Field.parse("Smith^John^A^Jr")
        
        XCTAssertEqual(field.repetitionCount, 1)
        XCTAssertEqual(field[0].value.raw, "Smith")
        XCTAssertEqual(field[1].value.raw, "John")
        XCTAssertEqual(field[2].value.raw, "A")
        XCTAssertEqual(field[3].value.raw, "Jr")
    }
    
    func testFieldWithRepetitions() {
        let field = Field.parse("Value1~Value2~Value3")
        
        XCTAssertEqual(field.repetitionCount, 3)
        XCTAssertEqual(field.repetition(at: 0)[0].value.raw, "Value1")
        XCTAssertEqual(field.repetition(at: 1)[0].value.raw, "Value2")
        XCTAssertEqual(field.repetition(at: 2)[0].value.raw, "Value3")
    }
    
    func testFieldComplexStructure() {
        let field = Field.parse("Smith^John^A~Jones^Jane^B")
        
        XCTAssertEqual(field.repetitionCount, 2)
        
        // First repetition
        let rep1 = field.repetition(at: 0)
        XCTAssertEqual(rep1.count, 3)
        XCTAssertEqual(rep1[0].value.raw, "Smith")
        XCTAssertEqual(rep1[1].value.raw, "John")
        XCTAssertEqual(rep1[2].value.raw, "A")
        
        // Second repetition
        let rep2 = field.repetition(at: 1)
        XCTAssertEqual(rep2.count, 3)
        XCTAssertEqual(rep2[0].value.raw, "Jones")
        XCTAssertEqual(rep2[1].value.raw, "Jane")
        XCTAssertEqual(rep2[2].value.raw, "B")
    }
    
    func testFieldEmpty() {
        let field = Field.parse("")
        
        XCTAssertEqual(field.repetitionCount, 1)
        XCTAssertTrue(field.isEmpty)
    }
    
    func testFieldFirstRepetition() {
        let field = Field.parse("Value1~Value2~Value3")
        let first = field.firstRepetition
        
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].value.raw, "Value1")
    }
    
    func testFieldOutOfBoundsRepetition() {
        let field = Field.parse("Value1")
        let rep = field.repetition(at: 5)
        
        XCTAssertTrue(rep.isEmpty)
    }
    
    func testFieldOutOfBoundsComponent() {
        let field = Field.parse("Value1")
        let component = field[5]
        
        XCTAssertTrue(component.isEmpty)
    }
    
    func testFieldSerialize() {
        let field = Field.parse("Smith^John^A~Jones^Jane^B")
        let serialized = field.serialize()
        
        XCTAssertEqual(serialized, "Smith^John^A~Jones^Jane^B")
    }
    
    func testFieldDescription() {
        let field = Field.parse("Smith^John^A")
        XCTAssertEqual(field.description, "Smith^John^A")
    }
    
    func testFieldAllRepetitions() {
        let field = Field.parse("A~B~C")
        let all = field.allRepetitions
        
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0][0].value.raw, "A")
        XCTAssertEqual(all[1][0].value.raw, "B")
        XCTAssertEqual(all[2][0].value.raw, "C")
    }
    
    func testFieldEquatable() {
        let field1 = Field.parse("Smith^John")
        let field2 = Field.parse("Smith^John")
        let field3 = Field.parse("Jones^Jane")
        
        XCTAssertEqual(field1, field2)
        XCTAssertNotEqual(field1, field3)
    }
    
    // MARK: - Complex Hierarchical Tests
    
    func testCompleteHierarchy() {
        // Test: Field > Repetitions > Components > Subcomponents
        let field = Field.parse("ID1^Name1&Given1&Middle1~ID2^Name2&Given2&Middle2")
        
        XCTAssertEqual(field.repetitionCount, 2)
        
        // First repetition, first component, first subcomponent
        XCTAssertEqual(field.repetition(at: 0)[0][0].raw, "ID1")
        
        // First repetition, second component, second subcomponent
        XCTAssertEqual(field.repetition(at: 0)[1][1].raw, "Given1")
        
        // Second repetition, first component
        XCTAssertEqual(field.repetition(at: 1)[0][0].raw, "ID2")
        
        // Second repetition, second component, third subcomponent
        XCTAssertEqual(field.repetition(at: 1)[1][2].raw, "Middle2")
    }
}
