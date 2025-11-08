require("solidity-coverage");

module.exports = {
  solidity: "0.8.28",
  paths: {
    sources: "./src",   // carpeta donde están los contratos
    tests: "./test",    // carpeta de tests
    cache: "./cache",
    artifacts: "./artifacts"
  },
};
