module.exports = {
  aliases: {
    classes: "./{filename}.scss",
  },
  environments: ["browser", "jest"],
  sortImports: false,
  useRelativePaths: false,
  importStatementFormatter({ importStatement }) {
    if (importStatement.includes("spec"))
      return importStatement.replace(/\'.*spec\//, "'spec/");
    if (importStatement.includes("accountants"))
      return importStatement.replace(/\'.*accountants\//, "'accountants/");
    if (importStatement.includes("components"))
      return importStatement.replace(/\'.*components\//, "'components/");
    return importStatement;
  },
};
