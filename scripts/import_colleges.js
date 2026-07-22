const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp({
  projectId: 'studysphere-app-3a480'
});
const db = getFirestore();

// Using a small sample of verified real Indian colleges for the mock seed.
// A full dataset from data.gov.in can be parsed into this format.
const collegesData = [
  {
    collegeId: "ssmm_pachora",
    collegeName: "SHRI SETH MURLIDHARJI MANSINGKA ARTS, SCIENCE & COMMERCE COLLEGE, PACHORA",
    shortName: "SSMM College Pachora",
    state: "Maharashtra",
    district: "Jalgaon",
    subDistrict: "Pachora",
    website: "ssmmcollege.ac.in",
    isActive: true,
    searchTerms: ["ssmm", "pachora"]
  },
  {
    collegeId: "iit_bombay",
    collegeName: "Indian Institute of Technology Bombay",
    shortName: "IIT Bombay",
    state: "Maharashtra",
    district: "Mumbai Suburban",
    subDistrict: "Powai",
    website: "iitb.ac.in",
    isActive: true,
    searchTerms: ["iitb", "iit bombay", "powai"]
  },
  {
    collegeId: "vjti_mumbai",
    collegeName: "Veermata Jijabai Technological Institute",
    shortName: "VJTI Mumbai",
    state: "Maharashtra",
    district: "Mumbai City",
    subDistrict: "Matunga",
    website: "vjti.ac.in",
    isActive: true,
    searchTerms: ["vjti", "matunga"]
  },
  {
    collegeId: "coep_pune",
    collegeName: "College of Engineering Pune",
    shortName: "COEP",
    state: "Maharashtra",
    district: "Pune",
    subDistrict: "Shivajinagar",
    website: "coep.org.in",
    isActive: true,
    searchTerms: ["coep", "pune"]
  }
];

async function importHierarchyAndColleges() {
  const batch = db.batch();
  const states = new Set();
  const districts = new Set();
  const subDistricts = new Set();

  for (const college of collegesData) {
    states.add(college.state);
    districts.add(`${college.state}|${college.district}`);
    subDistricts.add(`${college.state}|${college.district}|${college.subDistrict}`);

    // Process College
    const words = college.collegeName.toLowerCase().split(/[\s,;&]+/).filter(w => w.length > 2);
    const searchTermsLower = (college.searchTerms || []).map(t => t.toLowerCase());
    const uniqueTerms = [...new Set([...searchTermsLower, ...words])];

    const docRef = db.collection('colleges').doc(college.collegeId);
    batch.set(docRef, {
      ...college,
      searchTerms: uniqueTerms,
      createdAt: FieldValue.serverTimestamp()
    });
  }

  // Process States
  for (const state of states) {
    batch.set(db.collection('states').doc(state.toLowerCase().replace(/\s+/g, '_')), {
      name: state,
      createdAt: FieldValue.serverTimestamp()
    });
  }

  // Process Districts
  for (const dist of districts) {
    const [state, district] = dist.split('|');
    const docId = `${state}_${district}`.toLowerCase().replace(/\s+/g, '_');
    batch.set(db.collection('districts').doc(docId), {
      name: district,
      state: state,
      createdAt: FieldValue.serverTimestamp()
    });
  }

  // Process SubDistricts
  for (const sub of subDistricts) {
    const [state, district, subDistrict] = sub.split('|');
    const docId = `${state}_${district}_${subDistrict}`.toLowerCase().replace(/\s+/g, '_');
    batch.set(db.collection('subDistricts').doc(docId), {
      name: subDistrict,
      district: district,
      state: state,
      createdAt: FieldValue.serverTimestamp()
    });
  }

  try {
    await batch.commit();
    console.log("Successfully imported India Hierarchy and Colleges!");
  } catch (error) {
    console.error("Error importing data:", error);
  }
}

importHierarchyAndColleges();
