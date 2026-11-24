/* eslint-disable require-jsdoc */
// Single-function deployment entry: initialize the Admin SDK before loading handlers.
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();
exports.manageBookingMedication = require("./medication_functions").manageBookingMedication;
