// @ts-check
import { module } from "@prisma/composer";
import moontvService from "./service.mjs";

export default module("lunatv", ({ provision }) => {
  provision(moontvService);
});
