module.exports = {
  aliases: {
    classes: "./{filename}.scss",
  },
  environments: ["es2017", "browser", "jest", "builtin"],
  sortImports: false,
  useRelativePaths: false,
  excludes: ["./public/assets/packs/js/**"],
  maxLineLength: 120,
  moduleNameFormatter({ moduleName, pathToImportedModule }) {
    if (!pathToImportedModule) return moduleName;
    if (pathToImportedModule.includes("spec"))
      return pathToImportedModule
        .replace(/.*spec\//, "spec/")
        .replace(/(\.js.*|\.ts.*)/, "");
    if (pathToImportedModule.includes("test-utils"))
      return pathToImportedModule
        .replace(/.*test-utils\//, "test-utils/")
        .replace(/(\.js.*|\.ts.*)/, "");
    if (pathToImportedModule.includes("accountants"))
      return pathToImportedModule
        .replace(/.*accountants\//, "accountants/")
        .replace(/(\.js.*|\.ts.*)/, "");
    if (pathToImportedModule.includes("components"))
      return pathToImportedModule
        .replace(/.*components\//, "components/")
        .replace(/(\.js.*|\.ts.*)/, "");
    return moduleName;
  },
};
