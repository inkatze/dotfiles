module.exports = {
  aliases: {
    classes: "./{filename}.scss",
  },
  environments: ["browser", "jest"],
  excludes: ["./frontend/**/spec/**"],
  sortImports: false,
  importStatementFormatter({ importStatement }) {
    if (importStatement.includes("accountants"))
      return importStatement.replace(/\'.*accountants\//, "'accountants/");
    if (importStatement.includes("components"))
      return importStatement.replace(/\'.*components\//, "'components/");
    return importStatement;
  },
};
