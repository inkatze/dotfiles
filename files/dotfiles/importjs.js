module.exports = {
  aliases: {
    classes: "./{filename}.scss",
  },
  environments: ["browser", "jest"],
  sortImports: false,
  useRelativePaths: false,
  excludes: ["./public/assets/packs/js/**"],
  moduleNameFormatter({ moduleName, pathToImportedModule }) {
    if (!pathToImportedModule) return moduleName;
    if (pathToImportedModule.includes("spec"))
      return pathToImportedModule
        .replace(/.*spec\//, "spec/")
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
